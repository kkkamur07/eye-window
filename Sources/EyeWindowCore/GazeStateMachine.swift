import Foundation

/// Which physical side each numbered display occupies on the desktop.
public struct DualLayout: Equatable, Sendable {
    /// When `true`, display 1 is left and display 2 is right; when `false`, display 1 is right.
    public var display1IsLeft: Bool

    public init(display1IsLeft: Bool) {
        self.display1IsLeft = display1IsLeft
    }
}

/// Gaze sample from the gaze source (model yaw/pitch + attention).
public struct HeadPose: Equatable, Sendable {
    /// Gaze yaw in radians; negative = left, positive = right.
    public var yawRadians: Double
    /// Gaze pitch in radians (from the gaze model).
    public var pitchRadians: Double
    /// Whether the user is attending to a display (vs phone, desk, wall).
    public var onDisplayAttention: Bool

    public init(yawRadians: Double, pitchRadians: Double = 0, onDisplayAttention: Bool) {
        self.yawRadians = yawRadians
        self.pitchRadians = pitchRadians
        self.onDisplayAttention = onDisplayAttention
    }

    /// Legacy no-face frames were `(0, 0, onDisplayAttention: false)`; ignore for UI and switching.
    public var isValidGazeSample: Bool {
        onDisplayAttention || abs(yawRadians) > 1e-6 || abs(pitchRadians) > 1e-6
    }
}

/// Intent to move keyboard focus to a display after dwell is satisfied.
public struct FocusIntent: Equatable, Sendable {
    public var display: DisplayNumber

    public init(display: DisplayNumber) {
        self.display = display
    }
}

/// Debug snapshot after each gaze feed (menu bar / logs).
public struct GazeStatus: Equatable, Sendable {
    public var lockedDisplay: DisplayNumber?
    public var candidateDisplay: DisplayNumber?
    /// 0…1 while dwelling toward `candidateDisplay`; 0 when not dwelling.
    public var dwellProgress: Double
    public var mappedDisplay: DisplayNumber?
    public var onAttention: Bool
    public var stableFrameCount: Int

    public init(
        lockedDisplay: DisplayNumber?,
        candidateDisplay: DisplayNumber?,
        dwellProgress: Double,
        mappedDisplay: DisplayNumber?,
        onAttention: Bool,
        stableFrameCount: Int
    ) {
        self.lockedDisplay = lockedDisplay
        self.candidateDisplay = candidateDisplay
        self.dwellProgress = dwellProgress
        self.mappedDisplay = mappedDisplay
        self.onAttention = onAttention
        self.stableFrameCount = stableFrameCount
    }
}

/// Pure logic: dwell, focus lock, head-turn mapping, and attention gating.
public struct GazeStateMachine: Sendable {
    /// Ignore focus intents until the gaze smoother has enough frames (avoids first-frame spikes).
    public static let sessionWarmupFrames = 12
    /// Consecutive agreeing frames before dwell timer starts (~0.3 s at 10 FPS).
    public static let requiredStableFrames = 3
    public static let mediumDwellDuration: TimeInterval = 0.35
    /// ~12.6° — reduces accidental switches from small head movements.
    public static let yawThresholdRadians: Double = 0.22

    private var lockedDisplay: DisplayNumber?
    private var candidateDisplay: DisplayNumber?
    private var dwellStartTime: TimeInterval?
    private var lastMappedDisplay: DisplayNumber?
    private var stableFrameCount: Int = 0
    private var gazeSmoother = GazeVectorSmoother()
    private var framesSinceReset: Int = 0
    private var runtimeTuning: CalibrationTuning?
    private var lastHysteresisHeld = false

    public init() {}

    public mutating func resetClassifier() {
        gazeSmoother.reset()
        framesSinceReset = 0
        lockedDisplay = nil
        candidateDisplay = nil
        dwellStartTime = nil
        lastMappedDisplay = nil
        stableFrameCount = 0
        runtimeTuning = nil
        lastHysteresisHeld = false
    }

    /// Process one head-pose sample; returns a focus intent when dwell completes on a new display.
    /// Uses `thresholds` when provided; otherwise falls back to `yawThresholdRadians`.
    public mutating func feed(
        pose: HeadPose,
        layout: DualLayout,
        now: TimeInterval,
        profile: CalibrationProfile? = nil
    ) -> (intent: FocusIntent?, status: GazeStatus) {
        guard pose.isValidGazeSample else {
            resetDwellState()
            lastMappedDisplay = nil
            stableFrameCount = 0
            gazeSmoother.reset()
            framesSinceReset = 0
            return (nil, makeStatus(mapped: nil, onAttention: false, now: now))
        }

        framesSinceReset += 1
        runtimeTuning = profile?.tuning
        let mapped = mapDisplay(pose: pose, layout: layout, profile: profile)

        if let mapped {
            if mapped == lastMappedDisplay {
                stableFrameCount += 1
            } else {
                lastMappedDisplay = mapped
                stableFrameCount = 1
                if candidateDisplay != mapped {
                    Self.logMappedDisplay(pose: pose, mapped: mapped, profile: profile)
                }
            }
        } else {
            lastMappedDisplay = nil
            stableFrameCount = 0
            if candidateDisplay != nil {
                EyeWindowLog.info("gaze center (no display) yaw=\(String(format: "%.2f", pose.yawRadians))")
            }
            resetDwellState()
            return (nil, makeStatus(mapped: nil, onAttention: true, now: now))
        }

        let requiredStable = runtimeTuning?.requiredStableFrames ?? Self.requiredStableFrames
        guard stableFrameCount >= requiredStable, let mapped else {
            resetDwellState()
            return (nil, makeStatus(mapped: mapped, onAttention: true, now: now))
        }

        if mapped == lockedDisplay {
            resetDwellState()
            return (nil, makeStatus(mapped: mapped, onAttention: true, now: now))
        }

        if mapped != candidateDisplay {
            candidateDisplay = mapped
            dwellStartTime = now
            EyeWindowLog.info("dwell start → D\(mapped.rawValue)")
            return (nil, makeStatus(mapped: mapped, onAttention: true, now: now))
        }

        let dwellDuration = runtimeTuning?.mediumDwellDuration ?? Self.mediumDwellDuration
        guard let start = dwellStartTime,
              now >= start + dwellDuration
        else {
            return (nil, makeStatus(mapped: mapped, onAttention: true, now: now))
        }

        lockedDisplay = mapped
        candidateDisplay = nil
        dwellStartTime = nil
        EyeWindowLog.info("dwell complete → switch to D\(mapped.rawValue)")
        if profile != nil, framesSinceReset < Self.sessionWarmupFrames {
            return (nil, makeStatus(mapped: mapped, onAttention: true, now: now))
        }
        return (FocusIntent(display: mapped), makeStatus(mapped: mapped, onAttention: true, now: now))
    }

    private mutating func resetDwellState() {
        candidateDisplay = nil
        dwellStartTime = nil
    }

    private func makeStatus(mapped: DisplayNumber?, onAttention: Bool, now: TimeInterval) -> GazeStatus {
        var progress: Double = 0
        let dwellDuration = runtimeTuning?.mediumDwellDuration ?? Self.mediumDwellDuration
        if let candidate = candidateDisplay, let start = dwellStartTime {
            let elapsed = now - start
            progress = min(1, max(0, elapsed / dwellDuration))
            _ = candidate
        }
        return GazeStatus(
            lockedDisplay: lockedDisplay,
            candidateDisplay: candidateDisplay,
            dwellProgress: progress,
            mappedDisplay: mapped,
            onAttention: onAttention,
            stableFrameCount: stableFrameCount
        )
    }

    /// Last smoothed feature (for diagnostics); nil until at least one valid frame after reset.
    public var lastSmoothedFeature: GazeFeatureVector? { gazeSmoother.current }

    public var lockedFocusDisplay: DisplayNumber? { lockedDisplay }

    private mutating func mapDisplay(
        pose: HeadPose,
        layout: DualLayout,
        profile: CalibrationProfile?
    ) -> DisplayNumber? {
        if let profile {
            _ = layout
            let raw = GazeFeatureVector.fromPose(pose)
            let smoothed = gazeSmoother.push(raw)
            let dist = GazeCalibrationRules.distances(
                feature: smoothed,
                profile: profile,
                lockedDisplay: lockedDisplay
            )
            if dist.hysteresisHeld != lastHysteresisHeld, dist.hysteresisHeld, dist.nearest != dist.mapped {
                EyeWindowLog.info(
                    "hysteresis hold → D\(dist.mapped.rawValue) (nearest D\(dist.nearest.rawValue), need \(Int(profile.tuning.switchAdvantageRatio * 100))% margin; maha D1=\(String(format: "%.3f", dist.mahalanobisD1)) D2=\(String(format: "%.3f", dist.mahalanobisD2)))"
                )
            }
            lastHysteresisHeld = dist.hysteresisHeld
            return dist.mapped
        }
        let yaw = pose.yawRadians
        let lookingLeft = yaw < -Self.yawThresholdRadians
        let lookingRight = yaw > Self.yawThresholdRadians
        guard lookingLeft || lookingRight else { return nil }

        if layout.display1IsLeft {
            return lookingLeft ? .one : .two
        } else {
            return lookingLeft ? .two : .one
        }
    }

    private static func logMappedDisplay(
        pose: HeadPose,
        mapped: DisplayNumber,
        profile: CalibrationProfile?
    ) {
        let v = GazeFeatureVector.fromPose(pose)
        if let profile {
            let d1 = profile.display1
            let d2 = profile.display2
            EyeWindowLog.info(
                "map → D\(mapped.rawValue) vec=(\(String(format: "%.2f", v.gx)),\(String(format: "%.2f", v.gy)),\(String(format: "%.2f", v.gz))) yaw=\(String(format: "%.3f", pose.yawRadians)) cal D1 vec=(\(String(format: "%.2f", d1.gx)),\(String(format: "%.2f", d1.gy)),\(String(format: "%.2f", d1.gz))) D2 vec=(\(String(format: "%.2f", d2.gx)),\(String(format: "%.2f", d2.gy)),\(String(format: "%.2f", d2.gz)))"
            )
        } else {
            EyeWindowLog.info(
                "map → D\(mapped.rawValue) vec=(\(String(format: "%.2f", v.gx)),\(String(format: "%.2f", v.gy)),\(String(format: "%.2f", v.gz))) yaw=\(String(format: "%.3f", pose.yawRadians)) (uncalibrated)"
            )
        }
    }
}
