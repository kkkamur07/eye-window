import Foundation

/// Nearest mean-vector display mapping: compare **current** gaze to each screen's calibrated mean
/// `[gx, gy, gz, yaw, pitch]` using Mahalanobis distance (per-dimension std from calibration).
public enum GazeCalibrationRules {
    /// Fallback when no per-calibration tuning is available (legacy / tests).
    public static let defaultSwitchAdvantageRatio = 0.10

    public static func mapDisplay(
        pose: HeadPose,
        profile: CalibrationProfile,
        lockedDisplay: DisplayNumber? = nil
    ) -> DisplayNumber {
        mapDisplay(
            feature: GazeFeatureVector.fromPose(pose),
            profile: profile,
            lockedDisplay: lockedDisplay
        )
    }

    public struct DistanceResult: Equatable, Sendable {
        public var nearest: DisplayNumber
        public var mapped: DisplayNumber
        public var mahalanobisD1: Double
        public var mahalanobisD2: Double
        public var hysteresisHeld: Bool
    }

    public static func distances(
        feature: GazeFeatureVector,
        profile: CalibrationProfile,
        lockedDisplay: DisplayNumber? = nil,
        switchAdvantageRatio: Double? = nil
    ) -> DistanceResult {
        let advantage = switchAdvantageRatio ?? profile.tuning.switchAdvantageRatio
        let d1 = sqrt(feature.mahalanobisSquared(to: profile.display1, spread: profile.display1Spread))
        let d2 = sqrt(feature.mahalanobisSquared(to: profile.display2, spread: profile.display2Spread))
        let nearest: DisplayNumber = d1 <= d2 ? .one : .two
        var mapped = nearest
        var hysteresisHeld = false
        if let locked = lockedDisplay, nearest != locked {
            let near = min(d1, d2)
            let far = max(d1, d2)
            if near > 0, (far - near) / near < advantage {
                mapped = locked
                hysteresisHeld = true
            }
        }
        return DistanceResult(
            nearest: nearest,
            mapped: mapped,
            mahalanobisD1: d1,
            mahalanobisD2: d2,
            hysteresisHeld: hysteresisHeld
        )
    }

    public static func mapDisplay(
        feature: GazeFeatureVector,
        profile: CalibrationProfile,
        lockedDisplay: DisplayNumber? = nil,
        switchAdvantageRatio: Double? = nil
    ) -> DisplayNumber {
        distances(
            feature: feature,
            profile: profile,
            lockedDisplay: lockedDisplay,
            switchAdvantageRatio: switchAdvantageRatio
        ).mapped
    }

    /// Mahalanobis distance between the two display mean vectors (pooled spread; quality gate).
    public static func prototypeGap(profile: CalibrationProfile) -> Double {
        let pooled = GazeFeatureSpread.pooled(profile.display1Spread, profile.display2Spread)
        return sqrt(profile.display1.mahalanobisSquared(to: profile.display2, spread: pooled))
    }

    /// Nearest prototype by gaze yaw only (calibration diagnostic).
    public static func mapDisplayYawOnly(
        yawRadians: Double,
        profile: CalibrationProfile
    ) -> DisplayNumber {
        let d1 = abs(yawRadians - profile.display1.yawRadians)
        let d2 = abs(yawRadians - profile.display2.yawRadians)
        return d1 <= d2 ? .one : .two
    }
}
