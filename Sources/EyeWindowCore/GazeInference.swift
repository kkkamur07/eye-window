import AVFoundation
import CoreML
import Foundation

/// One gaze estimate from the Core ML model (live pipeline and tests).
public struct GazeSample: Equatable, Sendable {
    public var yawRadians: Double
    public var pitchRadians: Double
    public var onDisplayAttention: Bool

    public init(yawRadians: Double, pitchRadians: Double, onDisplayAttention: Bool) {
        self.yawRadians = yawRadians
        self.pitchRadians = pitchRadians
        self.onDisplayAttention = onDisplayAttention
    }

    /// Coordinator / state machine still consume `HeadPose` (yaw + attention only).
    public var headPose: HeadPose {
        HeadPose(yawRadians: yawRadians, pitchRadians: pitchRadians, onDisplayAttention: onDisplayAttention)
    }
}

/// Pitch-based on-display attention and logit decode (pure, testable).
public enum GazeInference {
    /// Looking down at phone/desk is more negative pitch; looking up is positive.
    /// Attentive when pitch is within this band (radians).
    /// Wide band — informational; runtime focus uses calibrated gaze yaw, not this flag.
    public static let pitchAttentionMinRadians: Double = -1.2
    public static let pitchAttentionMaxRadians: Double = 1.2

    public static func onDisplayAttention(pitchRadians: Double) -> Bool {
        pitchRadians > pitchAttentionMinRadians && pitchRadians < pitchAttentionMaxRadians
    }

    /// Softmax over bins → degrees → radians (`onnx_inference.py` / `GazeModelIO`).
    public static func decodeAngleRadians(logits: [Float]) -> Double {
        precondition(logits.count == GazeModelIO.logitBinCount)
        let maxLogit = logits.max() ?? 0
        var sumExp: Float = 0
        var expectation: Float = 0
        for (index, logit) in logits.enumerated() {
            let e = expf(logit - maxLogit)
            sumExp += e
            expectation += e * Float(index)
        }
        guard sumExp > 0 else { return 0 }
        let degrees = (expectation / sumExp) * GazeModelIO.binWidthDegrees - GazeModelIO.angleOffsetDegrees
        return Double(degrees) * Double.pi / 180
    }

    public static func gazeSample(yawLogits: [Float], pitchLogits: [Float]) -> GazeSample {
        let yaw = decodeAngleRadians(logits: yawLogits)
        let pitch = decodeAngleRadians(logits: pitchLogits)
        return GazeSample(
            yawRadians: yaw,
            pitchRadians: pitch,
            onDisplayAttention: onDisplayAttention(pitchRadians: pitch)
        )
    }

    public static func logits(from multiArray: MLMultiArray) -> [Float] {
        let count = multiArray.count
        var result = [Float](repeating: 0, count: count)
        let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
        for i in 0 ..< count {
            result[i] = ptr[i]
        }
        return result
    }
}

/// Built-in front camera frames are mirrored; external desk webcams are not (fixed per session).
public enum CameraMirroring {
    /// Built-in front-facing cameras are mirrored; external USB webcams are not.
    public static func shouldMirrorHorizontally(device: AVCaptureDevice) -> Bool {
        if device.deviceType == .externalUnknown {
            return false
        }
        return device.position == .front
    }
}
