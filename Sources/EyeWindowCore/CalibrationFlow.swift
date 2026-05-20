import Foundation

/// UI / coordinator phase for multi-target D1 → D2 calibration.
public enum CalibrationPhase: Equatable, Sendable {
    case idle
    case lookAt(display: DisplayNumber, target: CalibrationTarget)
    case complete

    public var isRecording: Bool {
        if case .lookAt = self { return true }
        return false
    }

    public var recordingDisplay: DisplayNumber? {
        if case .lookAt(let display, _) = self { return display }
        return nil
    }

    public var recordingTarget: CalibrationTarget? {
        if case .lookAt(_, let target) = self { return target }
        return nil
    }
}

/// Records gaze feature vectors per target (~12 s per dot × 3 per display).
public struct CalibrationFlow: Sendable {
    public static let targetSequence = CalibrationTarget.allCases
    public static let targetsPerDisplay = targetSequence.count
    public static let displaysCount = 2
    public static let totalSteps = targetsPerDisplay * displaysCount

    /// Per-dot recording window.
    public static let minStepDuration: TimeInterval = 12.0
    public static let minSamplesPerStep = Int(ceil(minStepDuration * GazeEngine.maxFrameRate)) + 1
    public static let maxSamplesPerStep = minSamplesPerStep + 15
    /// Force-advance a step if the gaze stream stalls (wall clock, not sample clock).
    public static let maxStepDuration: TimeInterval = 18.0
    public static let minSamplesIfStalled = max(20, minSamplesPerStep / 2)

    /// Approximate full calibration time (both displays, all targets).
    public static var estimatedTotalDuration: TimeInterval {
        minStepDuration * Double(totalSteps)
    }

    public private(set) var phase: CalibrationPhase = .idle
    private var samples: [GazeFeatureVector] = []
    private var stepStartTime: TimeInterval?
    private var display1AllSamples: [GazeFeatureVector] = []
    private var display2AllSamples: [GazeFeatureVector] = []
    /// Raw frames from the last completed calibration (for quality report).
    public private(set) var lastDisplay1Samples: [GazeFeatureVector] = []
    public private(set) var lastDisplay2Samples: [GazeFeatureVector] = []

    public var collectedSampleCount: Int { samples.count }

    /// 1-based step index while recording (e.g. 4/6).
    public var currentStepIndex: Int {
        guard case .lookAt(let display, let target) = phase,
              let ti = Self.targetSequence.firstIndex(of: target)
        else { return 0 }
        let displayOffset = display == .one ? 0 : Self.targetsPerDisplay
        return displayOffset + ti + 1
    }

    public var stepLabel: String {
        guard case .lookAt(let display, let target) = phase else { return "" }
        return "D\(display.rawValue) \(target.label)"
    }

    public init() {}

    public mutating func begin(now: TimeInterval = Date.timeIntervalSinceReferenceDate) {
        phase = .lookAt(display: .one, target: Self.targetSequence[0])
        samples = []
        stepStartTime = now
        display1AllSamples = []
        display2AllSamples = []
        lastDisplay1Samples = []
        lastDisplay2Samples = []
    }

    public mutating func reset() {
        phase = .idle
        samples = []
        stepStartTime = nil
        display1AllSamples = []
        display2AllSamples = []
        lastDisplay1Samples = []
        lastDisplay2Samples = []
    }

    /// Feed one gaze sample; returns profile when all steps finish.
    public mutating func feed(feature: GazeFeatureVector, now: TimeInterval) -> CalibrationProfile? {
        guard case .lookAt = phase else { return nil }
        samples.append(feature)
        return finishCurrentStepIfReady(now: now)
    }

    /// Wall-clock tick when gaze frames stall (no duplicate sample).
    public mutating func tick(now: TimeInterval) -> CalibrationProfile? {
        guard phase.isRecording else { return nil }
        return finishCurrentStepIfReady(now: now)
    }

    private mutating func finishCurrentStepIfReady(now: TimeInterval) -> CalibrationProfile? {
        guard case .lookAt(let display, let target) = phase,
              let start = stepStartTime
        else { return nil }

        let elapsed = now - start
        let enoughTime = elapsed >= Self.minStepDuration
        let enoughSamples = samples.count >= Self.minSamplesPerStep
        let capped = samples.count >= Self.maxSamplesPerStep
        let stalled = elapsed >= Self.maxStepDuration && samples.count >= Self.minSamplesIfStalled
        guard (enoughTime && enoughSamples) || capped || stalled else { return nil }

        let stepSamples = samples
        samples = []
        stepStartTime = now

        let trimmed = CalibrationQuality.trimInitialFrames(stepSamples)
        switch display {
        case .one:
            display1AllSamples.append(contentsOf: trimmed)
        case .two:
            display2AllSamples.append(contentsOf: trimmed)
        }

        guard let targetIndex = Self.targetSequence.firstIndex(of: target) else { return nil }

        if targetIndex + 1 < Self.targetSequence.count {
            phase = .lookAt(display: display, target: Self.targetSequence[targetIndex + 1])
            return nil
        }

        if display == .one {
            phase = .lookAt(display: .two, target: Self.targetSequence[0])
            return nil
        }

        lastDisplay1Samples = display1AllSamples
        lastDisplay2Samples = display2AllSamples
        let profile = CalibrationProfile.derive(
            display1Samples: display1AllSamples,
            display2Samples: display2AllSamples
        )
        phase = .complete
        return profile
    }
}
