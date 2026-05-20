import Foundation

/// Runtime switching parameters derived from a completed calibration (per user / session).
public struct CalibrationTuning: Equatable, Sendable, Codable {
    public var yawGapRadians: Double
    public var vecGap: Double
    /// Relative distance advantage required to leave the locked display (higher when prototypes overlap).
    public var switchAdvantageRatio: Double
    public var requiredStableFrames: Int
    public var mediumDwellDuration: TimeInterval

    public init(
        yawGapRadians: Double,
        vecGap: Double,
        switchAdvantageRatio: Double,
        requiredStableFrames: Int,
        mediumDwellDuration: TimeInterval
    ) {
        self.yawGapRadians = yawGapRadians
        self.vecGap = vecGap
        self.switchAdvantageRatio = switchAdvantageRatio
        self.requiredStableFrames = requiredStableFrames
        self.mediumDwellDuration = mediumDwellDuration
    }

    /// Estimate stickiness from measured prototype separation — no fixed user yaw bands.
    public static func derive(
        display1: GazeFeatureVector,
        display2: GazeFeatureVector,
        display1Spread: GazeFeatureSpread,
        display2Spread: GazeFeatureSpread
    ) -> CalibrationTuning {
        let yawGap = abs(display1.yawRadians - display2.yawRadians)
        let pooled = GazeFeatureSpread.pooled(display1Spread, display2Spread)
        let vecGap = sqrt(display1.mahalanobisSquared(to: display2, spread: pooled))

        // Tight prototypes → require a larger relative margin before switching away.
        let switchAdvantage = min(0.30, max(0.08, 0.34 - yawGap * 2.0))

        // Weak separation → more agreeing frames before dwell starts.
        let stableFrames = min(6, max(3, Int(ceil(3 + max(0, 0.10 - yawGap) / 0.022))))

        // Weak separation → longer dwell so brief boundary glances do not flip focus.
        let dwell = min(0.70, max(0.35, 0.35 + max(0, 0.10 - yawGap) * 2.2))

        return CalibrationTuning(
            yawGapRadians: yawGap,
            vecGap: vecGap,
            switchAdvantageRatio: switchAdvantage,
            requiredStableFrames: stableFrames,
            mediumDwellDuration: dwell
        )
    }
}
