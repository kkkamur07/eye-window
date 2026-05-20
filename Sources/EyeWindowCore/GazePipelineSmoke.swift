import CoreML
import Foundation

/// Shared helpers for gaze decode / vector smoke verification (self-check + GazeSmokeTest).
public enum GazePipelineSmoke {
    /// Build logits with a sharp peak at `bin` (0…89) for decode testing.
    public static func peakLogits(bin: Int, sharpness: Float = 20) -> [Float] {
        precondition((0 ..< GazeModelIO.logitBinCount).contains(bin))
        return (0 ..< GazeModelIO.logitBinCount).map { $0 == bin ? sharpness : -sharpness }
    }

    /// Expected decode in degrees for a sharp peak at `bin`.
    public static func expectedDegreesForPeak(bin: Int) -> Double {
        Double(bin) * Double(GazeModelIO.binWidthDegrees) - Double(GazeModelIO.angleOffsetDegrees)
    }

    /// Unit gaze direction from yaw/pitch (same as `GazeFeatureVector.fromGaze`).
    public static func gazeDirection(
        yawRadians: Double,
        pitchRadians: Double
    ) -> (gx: Double, gy: Double, gz: Double) {
        let v = GazeFeatureVector.fromGaze(yawRadians: yawRadians, pitchRadians: pitchRadians)
        return (v.gx, v.gy, v.gz)
    }

    public static func vectorLength(gx: Double, gy: Double, gz: Double) -> Double {
        sqrt(gx * gx + gy * gy + gz * gz)
    }

    /// Fill NCHW ImageNet-normalized tensor with flat gray (matches `scripts/smoke_gaze_pipeline.py`).
    public static func makeUniformGrayInput(gray: UInt8 = 128) throws -> MLMultiArray {
        let w = GazeModelIO.inputWidth
        let h = GazeModelIO.inputHeight
        let array = try MLMultiArray(shape: [1, 3, NSNumber(value: h), NSNumber(value: w)], dataType: .float32)
        let scale = Float(gray) / 255
        let mean = GazeModelIO.normalizeMean
        let std = GazeModelIO.normalizeStd
        let ptr = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
        let plane = w * h
        for c in 0 ..< 3 {
            let normalized = (scale - mean[c]) / std[c]
            let base = c * plane
            for i in 0 ..< plane {
                ptr[base + i] = normalized
            }
        }
        return array
    }

    /// Run Core ML on uniform gray; returns decoded gaze sample.
    public static func runUniformGrayInference(model: MLModel) throws -> GazeSample {
        let input = try makeUniformGrayInput()
        let out = try model.prediction(
            from: MLDictionaryFeatureProvider(dictionary: [GazeModelIO.inputName: MLFeatureValue(multiArray: input)])
        )
        guard let yawArray = out.featureValue(for: GazeModelIO.yawOutputName)?.multiArrayValue,
              let pitchArray = out.featureValue(for: GazeModelIO.pitchOutputName)?.multiArrayValue
        else {
            throw GazeModelError.loadFailed(underlying: NSError(domain: "GazePipelineSmoke", code: 1))
        }
        return GazeInference.gazeSample(
            yawLogits: GazeInference.logits(from: yawArray),
            pitchLogits: GazeInference.logits(from: pitchArray)
        )
    }
}
