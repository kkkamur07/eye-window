import AVFoundation
import CoreGraphics
import CoreImage
import CoreML
import CoreVideo
import Foundation

public enum CameraPermissionStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

public enum GazeEngineError: Error, Sendable {
    case cameraUnavailable
    case modelUnavailable
}

/// Webcam → optional mirror → fixed center crop → Core ML gaze → in-memory `HeadPose` stream (~10 FPS).
public final class GazeEngine: @unchecked Sendable {
    public static let maxFrameRate = 10.0
    private static let minFrameInterval = 1.0 / maxFrameRate
    private static let yawSmoothingAlpha = 0.3
    /// Center crop when no separate face detector — keep your head in the middle of the webcam.
    private static let centerCrop = CGRect(x: 0.2, y: 0.15, width: 0.6, height: 0.7)

    private let sessionQueue = DispatchQueue(label: "com.eyewindow.gaze.session")
    private var captureSession: AVCaptureSession?
    private var streamContinuation: AsyncStream<HeadPose>.Continuation?
    private var poseHandler: (@Sendable (HeadPose) -> Void)?
    private var lastProcessTime: CFAbsoluteTime = 0
    private var delegateHolder: VideoOutputDelegate?
    private var gazeModel: MLModel?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private var mirrorFramesHorizontally = false
    private var smoothedYaw: Double = 0
    private var smoothedPitch: Double = 0
    private var hasSmoothedAngles = false
    private var loggedInferenceFailure = false
    private var loggedFirstGazeFrame = false
    private var consecutiveInferenceFailures = 0

    public init() {}

    public static func cameraPermissionStatus() -> CameraPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    public static func requestCameraAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public func gazeStream() -> AsyncStream<HeadPose> {
        AsyncStream { continuation in
            self.sessionQueue.sync {
                self.streamContinuation = continuation
            }
            continuation.onTermination = { @Sendable [weak self] _ in
                self?.stop()
            }
        }
    }

    public func poseStream() -> AsyncStream<HeadPose> {
        gazeStream()
    }

    /// Optional sink for CLI tools where `AsyncStream` may not be pumped (e.g. `GazeSmokeTest --calibrate`).
    public func setPoseHandler(_ handler: (@Sendable (HeadPose) -> Void)?) {
        sessionQueue.sync {
            poseHandler = handler
        }
    }

    public func start() throws {
        var startError: GazeEngineError?
        sessionQueue.sync {
            guard captureSession == nil else { return }

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  let model = try? self.loadGazeModel()
            else {
                startError = .cameraUnavailable
                return
            }

            gazeModel = model
            mirrorFramesHorizontally = CameraMirroring.shouldMirrorHorizontally(device: device)

            let session = AVCaptureSession()
            session.sessionPreset = .medium

            guard session.canAddInput(input) else {
                startError = .cameraUnavailable
                return
            }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
            output.alwaysDiscardsLateVideoFrames = true

            let delegate = VideoOutputDelegate(engine: self)
            delegateHolder = delegate
            output.setSampleBufferDelegate(delegate, queue: sessionQueue)

            guard session.canAddOutput(output) else {
                startError = .cameraUnavailable
                return
            }
            session.addOutput(output)

            captureSession = session
            session.startRunning()
        }

        if let startError {
            throw startError
        }
    }

    public func stop() {
        sessionQueue.async {
            self.captureSession?.stopRunning()
            self.captureSession = nil
            self.delegateHolder = nil
            self.gazeModel = nil
            self.hasSmoothedAngles = false
            self.loggedInferenceFailure = false
            self.loggedFirstGazeFrame = false
            self.consecutiveInferenceFailures = 0
            self.streamContinuation?.finish()
            self.streamContinuation = nil
            self.poseHandler = nil
        }
    }

    private func loadGazeModel() throws -> MLModel {
        do {
            return try GazeModelLoader.loadModel()
        } catch {
            throw GazeEngineError.modelUnavailable
        }
    }

    fileprivate func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastProcessTime >= Self.minFrameInterval else { return }
        lastProcessTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let model = gazeModel
        else { return }

        let frameImage = prepareFrameImage(from: pixelBuffer)

        do {
            let input = try makeModelInput(frameImage: frameImage, faceBounds: Self.centerCrop)
            let output = try model.prediction(from: MLDictionaryFeatureProvider(
                dictionary: [GazeModelIO.inputName: MLFeatureValue(multiArray: input)]
            ))
            guard let yawArray = output.featureValue(for: GazeModelIO.yawOutputName)?.multiArrayValue,
                  let pitchArray = output.featureValue(for: GazeModelIO.pitchOutputName)?.multiArrayValue
            else {
                throw GazeEngineError.modelUnavailable
            }

            let sample = GazeInference.gazeSample(
                yawLogits: GazeInference.logits(from: yawArray),
                pitchLogits: GazeInference.logits(from: pitchArray)
            )
            consecutiveInferenceFailures = 0
            let yaw = smoothYaw(sample.yawRadians)
            if !loggedFirstGazeFrame {
                loggedFirstGazeFrame = true
                EyeWindowLog.info(
                    "gaze: first frame yaw=\(String(format: "%.3f", yaw)) pitch=\(String(format: "%.3f", sample.pitchRadians))"
                )
            }
            deliver(
                HeadPose(
                    yawRadians: yaw,
                    pitchRadians: smoothPitch(sample.pitchRadians),
                    onDisplayAttention: sample.onDisplayAttention
                )
            )
        } catch {
            consecutiveInferenceFailures += 1
            if !loggedInferenceFailure || consecutiveInferenceFailures == 30 {
                loggedInferenceFailure = true
                EyeWindowLog.info(
                    "gaze: inference failed (\(consecutiveInferenceFailures) frames) — \(error.localizedDescription)"
                )
            }
        }
    }

    private func deliver(_ pose: HeadPose) {
        poseHandler?(pose)
        streamContinuation?.yield(pose)
    }

    private func smoothYaw(_ raw: Double) -> Double {
        if hasSmoothedAngles {
            smoothedYaw = Self.yawSmoothingAlpha * raw + (1 - Self.yawSmoothingAlpha) * smoothedYaw
        } else {
            smoothedYaw = raw
            hasSmoothedAngles = true
        }
        return smoothedYaw
    }

    private func smoothPitch(_ raw: Double) -> Double {
        if hasSmoothedAngles {
            smoothedPitch = Self.yawSmoothingAlpha * raw + (1 - Self.yawSmoothingAlpha) * smoothedPitch
        } else {
            smoothedPitch = raw
        }
        return smoothedPitch
    }

    private func prepareFrameImage(from pixelBuffer: CVPixelBuffer) -> CIImage {
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        if mirrorFramesHorizontally {
            let width = image.extent.width
            image = image.transformed(by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: width, y: 0))
        }
        let extent = image.extent
        if extent.origin.x != 0 || extent.origin.y != 0 {
            image = image.transformed(by: CGAffineTransform(
                translationX: -extent.origin.x,
                y: -extent.origin.y
            ))
        }
        return image
    }

    private func makeModelInput(frameImage: CIImage, faceBounds: CGRect) throws -> MLMultiArray {
        let extent = frameImage.extent
        let width = extent.width
        let height = extent.height

        let pixelRect = CGRect(
            x: faceBounds.origin.x * width,
            y: faceBounds.origin.y * height,
            width: faceBounds.size.width * width,
            height: faceBounds.size.height * height
        )
        let marginX = pixelRect.width * 0.15
        let marginY = pixelRect.height * 0.15
        var cropRect = pixelRect.insetBy(dx: -marginX, dy: -marginY)
        cropRect = cropRect.intersection(extent)
        guard cropRect.width > 1, cropRect.height > 1 else {
            throw GazeEngineError.modelUnavailable
        }

        let cropped = frameImage.cropped(to: cropRect)
        let scaleX = CGFloat(GazeModelIO.inputWidth) / cropRect.width
        let scaleY = CGFloat(GazeModelIO.inputHeight) / cropRect.height
        let scaled = cropped.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = ciContext.createCGImage(
            scaled,
            from: CGRect(x: 0, y: 0, width: GazeModelIO.inputWidth, height: GazeModelIO.inputHeight)
        ) else {
            throw GazeEngineError.modelUnavailable
        }

        return try fillInputMultiArray(from: cgImage)
    }

    private func fillInputMultiArray(from image: CGImage) throws -> MLMultiArray {
        let w = GazeModelIO.inputWidth
        let h = GazeModelIO.inputHeight
        let array = try MLMultiArray(shape: [1, 3, NSNumber(value: h), NSNumber(value: w)], dataType: .float32)
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw GazeEngineError.modelUnavailable
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { throw GazeEngineError.modelUnavailable }
        let bytes = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        let mean = GazeModelIO.normalizeMean
        let std = GazeModelIO.normalizeStd
        let ptr = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
        let planeSize = w * h
        for y in 0 ..< h {
            for x in 0 ..< w {
                let offset = (y * w + x) * 4
                let r = Float(bytes[offset]) / 255
                let g = Float(bytes[offset + 1]) / 255
                let b = Float(bytes[offset + 2]) / 255
                let idx = y * w + x
                ptr[idx] = (r - mean[0]) / std[0]
                ptr[planeSize + idx] = (g - mean[1]) / std[1]
                ptr[2 * planeSize + idx] = (b - mean[2]) / std[2]
            }
        }
        return array
    }
}

private final class VideoOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private weak var engine: GazeEngine?

    init(engine: GazeEngine) {
        self.engine = engine
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        engine?.processSampleBuffer(sampleBuffer)
    }
}

@available(*, deprecated, message: "Use GazeEngine for live gaze inference")
public typealias HeadPoseEngine = GazeEngine

@available(*, deprecated, renamed: "GazeEngineError")
public typealias HeadPoseEngineError = GazeEngineError
