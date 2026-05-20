import CoreGraphics
import Foundation

/// Legacy Vision/heuristic mapping (issue 005). Live inference uses `GazeEngine` + `GazeInference`.
@available(*, deprecated, message: "Live inference uses GazeEngine; kept for unit tests only")
public enum HeadPoseMapper {
    public static let defaultMaxYawRadians = 0.45
    /// Slightly stricter so phone / leaning away does not count as on-display.
    public static let defaultMinRelativeFaceWidth = 0.10

    /// Face center X in normalized frame coordinates (0 = left, 1 = right).
    public static func yawFromNormalizedFaceCenter(
        normalizedCenterX: Double,
        maxYawRadians: Double = defaultMaxYawRadians
    ) -> Double {
        let offset = (normalizedCenterX - 0.5) * 2.0
        return offset * maxYawRadians
    }

    /// Face width as a fraction of frame width; large enough to count as attending a display.
    public static func onDisplayAttention(
        normalizedFaceWidth: Double,
        minRelativeWidth: Double = defaultMinRelativeFaceWidth
    ) -> Bool {
        normalizedFaceWidth >= minRelativeWidth
    }

    public static func headPose(
        faceBounds: CGRect,
        observationYaw: Double? = nil
    ) -> HeadPose {
        let yaw: Double
        if let observationYaw {
            yaw = observationYaw
        } else {
            yaw = yawFromNormalizedFaceCenter(normalizedCenterX: Double(faceBounds.midX))
        }
        let attention = onDisplayAttention(normalizedFaceWidth: Double(faceBounds.width))
        return HeadPose(yawRadians: yaw, onDisplayAttention: attention)
    }
}
