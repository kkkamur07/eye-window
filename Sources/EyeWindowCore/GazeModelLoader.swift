import CoreML
import Foundation

public enum GazeModelError: Error, Sendable {
    case modelNotFound
    case loadFailed(underlying: Error)
}

/// Bundled MobileNetV2 gaze Core ML model (logits → decode in GazeEngine, issue 012).
public enum GazeModelLoader {
    public static let bundleResourceName = "MobileNetV2Gaze"
    public static let bundleResourceExtension = "mlpackage"

    /// Loads `MobileNetV2Gaze.mlpackage` from the EyeWindowCore resource bundle.
    public static func loadModel(configuration: MLModelConfiguration = MLModelConfiguration()) throws -> MLModel {
        guard let url = Bundle.module.url(
            forResource: bundleResourceName,
            withExtension: bundleResourceExtension
        ) else {
            throw GazeModelError.modelNotFound
        }
        do {
            let compiledURL = try MLModel.compileModel(at: url)
            return try MLModel(contentsOf: compiledURL, configuration: configuration)
        } catch {
            throw GazeModelError.loadFailed(underlying: error)
        }
    }
}

/// Input/output contract for inference (issue 012). Angles are decoded from 90-bin logits in Swift.
public enum GazeModelIO {
    public static let inputName = "input"
    /// NCHW RGB, ImageNet-normalized float32 (see `GazeModelIO` preprocessing).
    public static let inputWidth = 448
    public static let inputHeight = 448
    public static let inputChannels = 3

    public static let yawOutputName = "yaw"
    public static let pitchOutputName = "pitch"
    public static let logitBinCount = 90

    /// Per-channel mean / std (RGB), applied after scaling uint8 crop to [0, 1].
    public static let normalizeMean: [Float] = [0.485, 0.456, 0.406]
    public static let normalizeStd: [Float] = [0.229, 0.224, 0.225]

    /// Softmax bin decode (yakhyo/gaze-estimation `onnx_inference.py`).
    public static let binWidthDegrees: Float = 4
    public static let angleOffsetDegrees: Float = 180
}
