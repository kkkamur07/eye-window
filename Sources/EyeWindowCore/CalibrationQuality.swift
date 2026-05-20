import Foundation

/// Stable gaze samples + quality gate for nearest-mean-vector calibration.
public enum CalibrationQuality {
    /// Minimum Mahalanobis-style prototype gap between D1/D2 means.
    public static let minVecSeparation: Double = 0.15
    /// Target replay accuracy on held-out calibration frames (warmup dropped, not stability-trimmed).
    public static let minReplayAccuracy: Double = 0.88
    /// Minimum yaw separation between display prototypes (identification is yaw-dominated).
    public static let minYawGapRadians: Double = 3.0 * .pi / 180.0
    /// Target yaw-only replay on calibration frames (diagnostic; same threshold as 5D replay).
    public static let minYawReplayAccuracy: Double = 0.88

    /// Initial frames dropped per calibration step before pooling / mean (≈2 s at gaze FPS).
    public static let initialFramesDroppedPerStep = Int(ceil(2.0 * GazeEngine.maxFrameRate))
    public static let stabilityWindow = 5
    /// Max std dev of gx/gy/gz over `stabilityWindow` frames to count as "steady gaze".
    public static let maxComponentStd: Double = 0.055
    public static let minStableSamplesPerDisplay = 15

    public struct Report: Equatable, Sendable {
        public var gxGap: Double
        public var vecGap: Double
        public var yawGapRadians: Double
        public var display1SpreadMax: Double
        public var display2SpreadMax: Double
        public var replayAccuracy: Double
        public var replayCorrect: Int
        public var replayTotal: Int
        public var yawReplayAccuracy: Double
        public var yawReplayCorrect: Int
        public var display1FramesUsed: Int
        public var display2FramesUsed: Int

        /// Hard gates: yaw gap, 5D prototype separation, and 5D replay must pass.
        public var passed: Bool {
            yawGapRadians >= CalibrationQuality.minYawGapRadians
                && vecGap >= CalibrationQuality.minVecSeparation
                && replayAccuracy >= CalibrationQuality.minReplayAccuracy
        }
    }

    /// Drop the first ~2 s of frames from one calibration step (settling / saccade to dot).
    public static func trimInitialFrames(_ samples: [GazeFeatureVector]) -> [GazeFeatureVector] {
        guard samples.count > initialFramesDroppedPerStep else { return samples }
        return Array(samples.dropFirst(initialFramesDroppedPerStep))
    }

    /// Drop warmup, keep only locally stable frames — used for prototype means and spread.
    public static func refineSamples(
        display1: [GazeFeatureVector],
        display2: [GazeFeatureVector]
    ) -> (display1: [GazeFeatureVector], display2: [GazeFeatureVector]) {
        var d1 = stableSamples(trimInitialFrames(display1))
        var d2 = stableSamples(trimInitialFrames(display2))
        if d1.count < minStableSamplesPerDisplay { d1 = trimInitialFrames(display1) }
        if d2.count < minStableSamplesPerDisplay { d2 = trimInitialFrames(display2) }
        return (d1, d2)
    }

    /// Frames used for replay scoring (warmup dropped; keeps head-movement frames that stable-trim would drop).
    public static func replaySamples(
        display1: [GazeFeatureVector],
        display2: [GazeFeatureVector]
    ) -> (display1: [GazeFeatureVector], display2: [GazeFeatureVector]) {
        (trimInitialFrames(display1), trimInitialFrames(display2))
    }

    public static func evaluate(
        profile: CalibrationProfile,
        display1Samples: [GazeFeatureVector],
        display2Samples: [GazeFeatureVector]
    ) -> Report {
        let d1m = profile.display1
        let d2m = profile.display2
        let gxGap = abs(d1m.gx - d2m.gx)
        let vecGap = GazeCalibrationRules.prototypeGap(profile: profile)
        let yawGap = abs(d1m.yawRadians - d2m.yawRadians)
        let replay = replaySamples(display1: display1Samples, display2: display2Samples)
        let refined = refineSamples(display1: display1Samples, display2: display2Samples)
        var correct = 0
        var yawCorrect = 0
        var total = 0
        var smoother = GazeVectorSmoother()
        for s in replay.display1 {
            total += 1
            let current = smoother.push(s)
            if profile.mappedDisplay(feature: current) == .one { correct += 1 }
            if GazeCalibrationRules.mapDisplayYawOnly(yawRadians: s.yawRadians, profile: profile) == .one {
                yawCorrect += 1
            }
        }
        smoother.reset()
        for s in replay.display2 {
            total += 1
            let current = smoother.push(s)
            if profile.mappedDisplay(feature: current) == .two { correct += 1 }
            if GazeCalibrationRules.mapDisplayYawOnly(yawRadians: s.yawRadians, profile: profile) == .two {
                yawCorrect += 1
            }
        }
        let accuracy = total > 0 ? Double(correct) / Double(total) : 0
        let yawAccuracy = total > 0 ? Double(yawCorrect) / Double(total) : 0
        return Report(
            gxGap: gxGap,
            vecGap: vecGap,
            yawGapRadians: yawGap,
            display1SpreadMax: profile.display1Spread.maxComponent,
            display2SpreadMax: profile.display2Spread.maxComponent,
            replayAccuracy: accuracy,
            replayCorrect: correct,
            replayTotal: total,
            yawReplayAccuracy: yawAccuracy,
            yawReplayCorrect: yawCorrect,
            display1FramesUsed: refined.display1.count,
            display2FramesUsed: refined.display2.count
        )
    }

    public static func failureLines(_ report: Report) -> [String] {
        var lines: [String] = []
        if report.yawGapRadians < minYawGapRadians {
            let deg = report.yawGapRadians * 180 / .pi
            let minDeg = minYawGapRadians * 180 / .pi
            lines.append(
                "yaw gap \(String(format: "%.1f", deg))° < \(String(format: "%.1f", minDeg))° — turn your head toward each monitor (not only eyes)"
            )
        }
        if report.vecGap < minVecSeparation {
            lines.append(
                "prototype gap \(String(format: "%.3f", report.vecGap)) < \(minVecSeparation) — turn your head toward each monitor (not only eyes); hold each dot ~\(Int(CalibrationFlow.minStepDuration))s"
            )
        }
        if report.replayAccuracy < minReplayAccuracy {
            let pct = Int((report.replayAccuracy * 100).rounded())
            let need = Int((minReplayAccuracy * 100).rounded())
            lines.append(
                "replay \(report.replayCorrect)/\(report.replayTotal) (\(pct)%) < \(need)% — hold steady on each dot; use center, left, and right on each screen"
            )
        }
        return lines
    }

    public static func advisoryLines(_ report: Report) -> [String] {
        var lines: [String] = []
        if report.yawReplayAccuracy < minYawReplayAccuracy {
            let pct = Int((report.yawReplayAccuracy * 100).rounded())
            let need = Int((minYawReplayAccuracy * 100).rounded())
            lines.append(
                "yaw-only replay \(report.yawReplayCorrect)/\(report.replayTotal) (\(pct)%) < \(need)% — prototypes may not separate cleanly on yaw alone"
            )
        }
        return lines
    }

    private static func stableSamples(_ samples: [GazeFeatureVector]) -> [GazeFeatureVector] {
        guard samples.count >= stabilityWindow else { return samples }
        var out: [GazeFeatureVector] = []
        for i in (stabilityWindow - 1) ..< samples.count {
            let window = Array(samples[(i - stabilityWindow + 1) ... i])
            if componentStd(window) <= maxComponentStd {
                out.append(samples[i])
            }
        }
        return out
    }

    private static func componentStd(_ window: [GazeFeatureVector]) -> Double {
        func std(_ values: [Double]) -> Double {
            guard values.count > 1 else { return 0 }
            let mean = values.reduce(0, +) / Double(values.count)
            let varSum = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
            return sqrt(varSum / Double(values.count))
        }
        let gx = window.map(\.gx)
        let gy = window.map(\.gy)
        let gz = window.map(\.gz)
        return max(std(gx), std(gy), std(gz))
    }

}
