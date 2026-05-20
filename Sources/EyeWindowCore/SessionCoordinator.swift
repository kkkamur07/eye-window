import Foundation

/// Owns session lifecycle, display gating, and the Core ML gaze pipeline (`GazeEngine`).
@MainActor
public final class SessionCoordinator: ObservableObject {
    @Published public private(set) var isSessionActive = false
    @Published public private(set) var isGazePaused = false
    @Published public private(set) var displayLayout: DisplayLayout = .notDual
    @Published public private(set) var isCameraBlocked = false
    @Published public private(set) var isAccessibilityBlocked = false
    @Published public private(set) var latestPoseLabel: String?
    @Published public private(set) var latestYawRadians: Double?
    @Published public private(set) var latestPitchRadians: Double?
    @Published public private(set) var latestGx: Double?
    @Published public private(set) var latestGy: Double?
    @Published public private(set) var latestGz: Double?
    /// True after at least one real gaze model frame (not a legacy zero placeholder).
    @Published public private(set) var hasLiveGazeFrames = false
    @Published public private(set) var calibrationSampleProgress: Int = 0
    @Published public private(set) var currentFocusDisplay: DisplayNumber?
    @Published public private(set) var activeAppName: String?
    @Published public private(set) var gazeStatus: GazeStatus?
    @Published public private(set) var recentLogLines: [String] = []
    @Published public private(set) var calibrationPhase: CalibrationPhase = .idle
    @Published public private(set) var isCalibrated: Bool
    /// Which display should show the on-screen calibration dot (nil = hide).
    @Published public private(set) var calibrationDotDisplay: DisplayNumber?
    /// Set when calibration fails quality gate; cleared on Recalibrate.
    @Published public private(set) var calibrationNeedsAttention = false
    /// Implicit learning rows saved to `implicit_gaze_dataset.jsonl`.
    @Published public private(set) var implicitDatasetStats = ImplicitGazeDatasetStore.Stats(total: 0, display1: 0, display2: 0)

    public let focusHistory = FocusHistory()
    public let calibrationStore: CalibrationStore
    public var onFocusIntent: ((DisplayNumber) -> Void)?
    /// AppKit red-dot overlay (menu bar target sets this on launch).
    public weak var calibrationDotPresenter: CalibrationDotPresenting?

    private var gazeEngine: GazeEngine?
    private var poseTask: Task<Void, Never>?
    private var calibrationTickTask: Task<Void, Never>?
    private var gazeStateMachine = GazeStateMachine()
    private var calibrationFlow = CalibrationFlow()
    private var lastGazeTraceTime: TimeInterval = 0
    private var lastGazeIdleLogTime: TimeInterval = 0
    private let gazeSampleBuffer = GazeSampleBuffer()
    private let implicitGazeStore = ImplicitGazeDatasetStore.shared

    public init(calibrationStore: CalibrationStore = .shared) {
        self.calibrationStore = calibrationStore
        isCalibrated = calibrationStore.isCalibrated
        implicitDatasetStats = implicitGazeStore.stats()
        EyeWindowLog.onLine = { [weak self] line in
            Task { @MainActor in
                self?.appendLogLine(line)
            }
        }
        refreshDisplayLayout()
    }

    public func refreshDisplayLayout() {
        displayLayout = DisplayMonitor.currentDisplays()
        applyCalibrationDotUI()
    }

    public func startSession() {
        EyeWindowLog.clearRecent()
        recentLogLines = []
        EyeWindowLog.info("session start (gaze: center-crop model, no face detector)")
        Task {
            await startSessionAsync()
        }
    }

    public func toggleGazePause() {
        isGazePaused.toggle()
        EyeWindowLog.info(isGazePaused ? "gaze paused" : "gaze resumed")
        if isGazePaused {
            stopGazePipeline()
            latestPoseLabel = nil
            latestYawRadians = nil
            latestPitchRadians = nil
            latestGx = nil
            latestGy = nil
            latestGz = nil
            hasLiveGazeFrames = false
            gazeStatus = nil
            calibrationDotDisplay = nil
            calibrationDotPresenter?.hideCalibrationDot()
        } else if isSessionActive, !isCameraBlocked {
            startGazePipeline()
            applyCalibrationDotUI()
        }
    }

    public func stopSession() {
        EyeWindowLog.info("session stop")
        stopGazePipeline()
        isSessionActive = false
        isGazePaused = false
        isCameraBlocked = false
        isAccessibilityBlocked = false
        latestPoseLabel = nil
        latestYawRadians = nil
        latestPitchRadians = nil
        latestGx = nil
        latestGy = nil
        latestGz = nil
        hasLiveGazeFrames = false
        currentFocusDisplay = nil
        activeAppName = nil
        gazeStatus = nil
        calibrationSampleProgress = 0
        gazeStateMachine = GazeStateMachine()
        calibrationFlow.reset()
        calibrationPhase = .idle
        calibrationDotDisplay = nil
        calibrationNeedsAttention = false
        stopCalibrationTick()
        calibrationDotPresenter?.hideCalibrationDot()
        isCalibrated = calibrationStore.isCalibrated
        focusHistory.reset()
        gazeSampleBuffer.reset()
        refreshImplicitStats()
    }

    /// Label the recent gaze window with the display under the mouse click.
    public func recordImplicitMouseClick(at screenPoint: CGPoint) {
        guard isSessionActive, !isCameraBlocked, !isGazePaused else { return }
        guard case .dual = displayLayout,
              let bounds = DisplayMonitor.dualDisplayBounds()
        else { return }
        let display = FocusDisplayMapping.display(
            for: screenPoint,
            display1Frame: bounds.display1,
            display2Frame: bounds.display2
        )
        recordImplicitLabel(display: display, source: .mouseClick, mousePoint: screenPoint)
    }

    /// Label recent gaze when system focus moves to an app on a display.
    public func recordImplicitAppFocus(display: DisplayNumber) {
        guard isSessionActive, !isCameraBlocked, !isGazePaused else { return }
        recordImplicitLabel(display: display, source: .appFocus, mousePoint: nil)
    }

    public func clearImplicitDataset() {
        implicitGazeStore.clear()
        refreshImplicitStats()
        EyeWindowLog.info("implicit dataset cleared")
    }

    private func recordImplicitLabel(
        display: DisplayNumber,
        source: ImplicitLabelSource,
        mousePoint: CGPoint?
    ) {
        let timestamp = Date.timeIntervalSinceReferenceDate
        guard let feature = gazeSampleBuffer.representativeFeature(at: timestamp) else {
            if gazeSampleBuffer.frameCount < GazeSampleBuffer.defaultMinFrames {
                EyeWindowLog.info("implicit: skip \(source.rawValue) — waiting for gaze frames")
            }
            return
        }
        let sample = ImplicitGazeSample(
            timestamp: timestamp,
            display: display,
            feature: feature,
            source: source,
            mousePoint: mousePoint
        )
        guard implicitGazeStore.append(sample) else { return }
        refreshImplicitStats()
        let src = source == .mouseClick ? "click" : "focus"
        EyeWindowLog.info(
            "implicit +1 D\(sample.display.rawValue) (\(src)) vec=(\(String(format: "%.2f", sample.gx)),\(String(format: "%.2f", sample.gy)),\(String(format: "%.2f", sample.gz))) yaw=\(String(format: "%.3f", sample.yawRadians)) total=\(implicitDatasetStats.total)"
        )
    }

    private func refreshImplicitStats() {
        implicitDatasetStats = implicitGazeStore.stats()
    }

    public func recalibrate() {
        guard isSessionActive, !isCameraBlocked else { return }
        calibrationStore.clear()
        isCalibrated = false
        calibrationNeedsAttention = false
        gazeStateMachine = GazeStateMachine()
        gazeStatus = nil
        beginCalibrationFlow()
        EyeWindowLog.info("recalibrate started")
    }

    public func setFocus(display: DisplayNumber, appName: String?) {
        currentFocusDisplay = display
        activeAppName = appName
    }

    public func setAccessibilityBlocked(_ blocked: Bool) {
        isAccessibilityBlocked = blocked
    }

    private func appendLogLine(_ line: String) {
        recentLogLines.append(line)
        if recentLogLines.count > 16 {
            recentLogLines.removeFirst(recentLogLines.count - 16)
        }
    }

    private func startSessionAsync() async {
        refreshDisplayLayout()

        var status = GazeEngine.cameraPermissionStatus()
        if status == .notDetermined {
            let granted = await GazeEngine.requestCameraAccess()
            status = granted ? .authorized : .denied
        }

        isSessionActive = true

        guard status == .authorized else {
            isCameraBlocked = true
            latestPoseLabel = nil
            latestYawRadians = nil
            latestPitchRadians = nil
            latestGx = nil
            latestGy = nil
            latestGz = nil
            EyeWindowLog.info("camera blocked")
            return
        }

        isCameraBlocked = false
        isCalibrated = calibrationStore.load() != nil
        startGazePipeline()

        refreshImplicitStats()
        if !isCalibrated {
            EyeWindowLog.info(
                "implicit learning: use each display normally — clicks (and app focus) save labeled gaze to implicit_gaze_dataset.jsonl"
            )
            EyeWindowLog.info(
                "  path: \(implicitGazeStore.fileURL.path)"
            )
        } else if let profile = calibrationStore.profile {
            let gap = GazeCalibrationRules.prototypeGap(profile: profile)
            let yawGap = abs(profile.display1.yawRadians - profile.display2.yawRadians)
            EyeWindowLog.info(
                "calibration loaded D1 yaw=\(String(format: "%.2f", profile.display1.yawRadians)) D2 yaw=\(String(format: "%.2f", profile.display2.yawRadians)) gap=\(String(format: "%.3f", gap))"
            )
            EyeWindowLog.info(
                "  D1 vec=(\(String(format: "%.2f", profile.display1.gx)),\(String(format: "%.2f", profile.display1.gy)),\(String(format: "%.2f", profile.display1.gz))) D2 vec=(\(String(format: "%.2f", profile.display2.gx)),\(String(format: "%.2f", profile.display2.gy)),\(String(format: "%.2f", profile.display2.gz)))"
            )
            EyeWindowLog.info(
                "  tuning: hysteresis=\(Int((profile.tuning.switchAdvantageRatio * 100).rounded()))% stable=\(profile.tuning.requiredStableFrames) dwell=\(String(format: "%.2f", profile.tuning.mediumDwellDuration))s"
            )
            if yawGap < CalibrationQuality.minYawGapRadians {
                EyeWindowLog.info(
                    "  warn: prototypes only \(String(format: "%.1f", yawGap * 180 / .pi))° apart in yaw (need ≥\(String(format: "%.1f", CalibrationQuality.minYawGapRadians * 180 / .pi))°) — recalibrate with head turns"
                )
            }
        }
    }

    private func beginCalibrationFlow() {
        calibrationFlow.begin()
        calibrationPhase = calibrationFlow.phase
        calibrationSampleProgress = 0
        applyCalibrationDotUI()
        startCalibrationTick()
        calibrationNeedsAttention = false
        EyeWindowLog.info(
            "calibration: 6 dots (center/left/right per screen), ~\(Int(CalibrationFlow.minStepDuration))s each, ~\(Int(CalibrationFlow.estimatedTotalDuration))s total — turn head toward each monitor"
        )
        EyeWindowLog.info(
            "calibration: \(calibrationFlow.stepLabel) dot 1/\(CalibrationFlow.totalSteps)"
        )
    }

    private func finishCalibration(_ profile: CalibrationProfile) {
        let refined = CalibrationQuality.refineSamples(
            display1: calibrationFlow.lastDisplay1Samples,
            display2: calibrationFlow.lastDisplay2Samples
        )
        let report = CalibrationQuality.evaluate(
            profile: profile,
            display1Samples: refined.display1,
            display2Samples: refined.display2
        )
        guard report.passed else {
            EyeWindowLog.info("calibration rejected — quality gate failed:")
            for line in CalibrationQuality.failureLines(report) {
                EyeWindowLog.info("  \(line)")
            }
            for line in CalibrationQuality.advisoryLines(report) {
                EyeWindowLog.info("  \(line)")
            }
            EyeWindowLog.info(
                "  measured: 5D gap=\(String(format: "%.3f", report.vecGap)) yaw=\(String(format: "%.1f", report.yawGapRadians * 180 / .pi))° gx=\(String(format: "%.3f", report.gxGap))"
            )
            EyeWindowLog.info(
                "  calibration paused — choose Recalibrate in the menu (turn head toward each screen, not only eyes)"
            )
            calibrationFlow.reset()
            calibrationPhase = .idle
            calibrationDotDisplay = nil
            calibrationSampleProgress = 0
            calibrationNeedsAttention = true
            stopCalibrationTick()
            applyCalibrationDotUI()
            isCalibrated = calibrationStore.isCalibrated
            return
        }

        calibrationStore.save(profile)
        isCalibrated = true
        calibrationNeedsAttention = false
        calibrationFlow.reset()
        calibrationPhase = .idle
        calibrationDotDisplay = nil
        calibrationSampleProgress = 0
        stopCalibrationTick()
        applyCalibrationDotUI()
        let mid = (profile.display1.yawRadians + profile.display2.yawRadians) / 2
        let yawGap = abs(profile.display1.yawRadians - profile.display2.yawRadians)
        EyeWindowLog.info("calibration saved — Mahalanobis nearest mean (\(GazeVectorSmoother.windowSize)-frame current):")
        EyeWindowLog.info(
            "  D1 vec=(\(String(format: "%.3f", profile.display1.gx)),\(String(format: "%.3f", profile.display1.gy)),\(String(format: "%.3f", profile.display1.gz))) yaw=\(String(format: "%.3f", profile.display1.yawRadians)) std max=\(String(format: "%.3f", report.display1SpreadMax))"
        )
        EyeWindowLog.info(
            "  D2 vec=(\(String(format: "%.3f", profile.display2.gx)),\(String(format: "%.3f", profile.display2.gy)),\(String(format: "%.3f", profile.display2.gz))) yaw=\(String(format: "%.3f", profile.display2.yawRadians)) std max=\(String(format: "%.3f", report.display2SpreadMax))"
        )
        EyeWindowLog.info("  gap=\(String(format: "%.3f", report.vecGap)) (min \(CalibrationQuality.minVecSeparation)) gx=\(String(format: "%.3f", report.gxGap))")
        EyeWindowLog.info(
            "  replay \(report.replayCorrect)/\(report.replayTotal) (\(Int(report.replayAccuracy * 100))%)"
        )
        EyeWindowLog.info(
            "  yaw gap=\(String(format: "%.3f", yawGap)) rad (\(String(format: "%.1f", yawGap * 180 / .pi))°) mid=\(String(format: "%.3f", mid))"
        )
        EyeWindowLog.info(
            "  tuning: hysteresis=\(Int((profile.tuning.switchAdvantageRatio * 100).rounded()))% stable=\(profile.tuning.requiredStableFrames) dwell=\(String(format: "%.2f", profile.tuning.mediumDwellDuration))s (from your calibration)"
        )
        EyeWindowLog.info(
            "  yaw-only replay \(report.yawReplayCorrect)/\(report.replayTotal) (\(Int(report.yawReplayAccuracy * 100))%)"
        )
        gazeStateMachine.resetClassifier()
    }

    private func applyCalibrationDotUI() {
        guard isSessionActive, !isCameraBlocked else {
            calibrationDotDisplay = nil
            calibrationDotPresenter?.hideCalibrationDot()
            return
        }
        guard case .lookAt(let display, let target) = calibrationPhase else {
            calibrationDotDisplay = nil
            calibrationDotPresenter?.hideCalibrationDot()
            return
        }
        calibrationDotDisplay = display

        guard case .dual(let dual) = displayLayout,
              let frame = DisplayMonitor.screenFrame(for: display, layout: dual)
        else {
            calibrationDotPresenter?.hideCalibrationDot()
            EyeWindowLog.info("calibration dot hidden (need dual displays)")
            return
        }
        calibrationDotPresenter?.showCalibrationDot(inScreenFrame: frame, target: target)
    }

    private func startCalibrationTick() {
        stopCalibrationTick()
        calibrationTickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard self.calibrationPhase.isRecording else { continue }
                self.processCalibrationTick()
            }
        }
    }

    private func stopCalibrationTick() {
        calibrationTickTask?.cancel()
        calibrationTickTask = nil
    }

    private func processCalibrationTick() {
        let now = Date.timeIntervalSinceReferenceDate
        if let profile = calibrationFlow.tick(now: now) {
            finishCalibration(profile)
            return
        }
        applyCalibrationPhaseFromFlow()
    }

    private func startGazePipeline() {
        stopGazePipeline()

        hasLiveGazeFrames = false
        let engine = GazeEngine()
        gazeEngine = engine
        let stream = engine.gazeStream()

        gazeStateMachine.resetClassifier()

        do {
            try engine.start()
            EyeWindowLog.info("gaze pipeline started (~\(Int(GazeEngine.maxFrameRate)) FPS)")
        } catch {
            isCameraBlocked = true
            latestPoseLabel = nil
            latestYawRadians = nil
            latestPitchRadians = nil
            latestGx = nil
            latestGy = nil
            latestGz = nil
            EyeWindowLog.info("gaze pipeline failed")
            stopGazePipeline()
            return
        }

        poseTask = Task { [weak self] in
            for await pose in stream {
                guard let self, !Task.isCancelled else { return }
                self.processPoseForGazeSwitch(pose)
            }
        }
    }

    private func stopGazePipeline() {
        poseTask?.cancel()
        poseTask = nil
        gazeEngine?.stop()
        gazeEngine = nil
        stopCalibrationTick()
    }

    private var isGazeSwitchingArmed: Bool {
        isSessionActive && !isGazePaused && !isCameraBlocked && isCalibrated
            && !calibrationPhase.isRecording
            && {
                if case .dual = displayLayout { return true }
                return false
            }()
    }

    private func processPoseForGazeSwitch(_ pose: HeadPose) {
        guard !isGazePaused else { return }
        guard pose.isValidGazeSample else { return }

        hasLiveGazeFrames = true
        let v = GazeFeatureVector.fromPose(pose)
        gazeSampleBuffer.append(v, at: Date.timeIntervalSinceReferenceDate)
        latestGx = v.gx
        latestGy = v.gy
        latestGz = v.gz
        latestYawRadians = pose.yawRadians
        latestPitchRadians = pose.pitchRadians

        if calibrationPhase.isRecording {
            latestPoseLabel = "cal"
            processPoseForCalibration(pose)
            return
        }

        if case .dual = displayLayout, let profile = calibrationStore.profile {
            latestPoseLabel = GazeCalibrationRules.poseLabel(pose: pose, profile: profile)
        } else {
            latestPoseLabel = Self.poseLabelUncalibrated(for: pose)
        }

        let now = Date.timeIntervalSinceReferenceDate
        if isGazeSwitchingArmed, case .dual(let dualLayout) = displayLayout {
            let result = gazeStateMachine.feed(
                pose: pose,
                layout: dualLayout,
                now: now,
                profile: calibrationStore.profile
            )
            gazeStatus = result.status
            traceGaze(pose: pose, profile: calibrationStore.profile, now: now)

            if let intent = result.intent {
                EyeWindowLog.info("focus intent → D\(intent.display.rawValue)")
                currentFocusDisplay = intent.display
                onFocusIntent?(intent.display)
            }
        } else {
            logGazeIdleReason(now: now)
        }
    }

    private func traceGaze(pose: HeadPose, profile: CalibrationProfile?, now: TimeInterval) {
        guard now - lastGazeTraceTime >= 1.0 else { return }
        lastGazeTraceTime = now
        let raw = GazeFeatureVector.fromPose(pose)
        if let profile, let smoothed = gazeStateMachine.lastSmoothedFeature {
            let locked = gazeStateMachine.lockedFocusDisplay
            let dist = GazeCalibrationRules.distances(
                feature: smoothed,
                profile: profile,
                lockedDisplay: locked
            )
            let label = "D\(dist.mapped.rawValue)"
            let lockNote = locked.map { " locked=D\($0.rawValue)" } ?? ""
            let holdNote = dist.hysteresisHeld ? " hold" : ""
            let nearestNote = dist.nearest != dist.mapped ? " nearest=D\(dist.nearest.rawValue)" : ""
            EyeWindowLog.info(
                "gaze raw=(\(String(format: "%.2f", raw.gx)),\(String(format: "%.2f", raw.gy)),\(String(format: "%.2f", raw.gz))) yaw=\(String(format: "%.3f", pose.yawRadians)) smooth=(\(String(format: "%.2f", smoothed.gx)),\(String(format: "%.2f", smoothed.gy)),\(String(format: "%.2f", smoothed.gz))) → \(label)\(lockNote)\(holdNote)\(nearestNote) maha D1=\(String(format: "%.3f", dist.mahalanobisD1)) D2=\(String(format: "%.3f", dist.mahalanobisD2))"
            )
        } else if let profile {
            let mapped = profile.mappedDisplay(feature: raw)
            EyeWindowLog.info(
                "gaze vec=(\(String(format: "%.2f", raw.gx)),\(String(format: "%.2f", raw.gy)),\(String(format: "%.2f", raw.gz))) yaw=\(String(format: "%.3f", pose.yawRadians)) → D\(mapped.rawValue) (warming up smoother)"
            )
        } else {
            EyeWindowLog.info(
                "gaze vec=(\(String(format: "%.2f", raw.gx)),\(String(format: "%.2f", raw.gy)),\(String(format: "%.2f", raw.gz))) yaw=\(String(format: "%.3f", pose.yawRadians)) (not calibrated)"
            )
        }
    }

    private func logGazeIdleReason(now: TimeInterval) {
        guard now - lastGazeIdleLogTime >= 5.0 else { return }
        lastGazeIdleLogTime = now
        if !isSessionActive { return }
        if isGazePaused {
            EyeWindowLog.info("gaze idle: paused")
            return
        }
        if isCameraBlocked {
            EyeWindowLog.info("gaze idle: camera blocked")
            return
        }
        if !isCalibrated {
            EyeWindowLog.info("gaze idle: not calibrated")
            return
        }
        if calibrationPhase.isRecording {
            EyeWindowLog.info("gaze idle: calibrating")
            return
        }
        if case .dual = displayLayout {} else {
            EyeWindowLog.info("gaze idle: need 2 displays")
        }
    }

    private func processPoseForCalibration(_ pose: HeadPose) {
        let feature = GazeFeatureVector.fromPose(pose)
        if calibrationFlow.collectedSampleCount % 5 == 0 {
            EyeWindowLog.info(
                "cal sample vec=(\(String(format: "%.3f", feature.gx)),\(String(format: "%.3f", feature.gy)),\(String(format: "%.3f", feature.gz))) yaw=\(String(format: "%.3f", feature.yawRadians))"
            )
        }
        let now = Date.timeIntervalSinceReferenceDate
        if let profile = calibrationFlow.feed(feature: feature, now: now) {
            finishCalibration(profile)
            return
        }
        applyCalibrationPhaseFromFlow()
    }

    private func applyCalibrationPhaseFromFlow() {
        calibrationSampleProgress = calibrationFlow.collectedSampleCount
        guard calibrationFlow.phase != calibrationPhase else { return }
        calibrationPhase = calibrationFlow.phase
        calibrationSampleProgress = 0
        applyCalibrationDotUI()
        if case .lookAt(display: .two, target: .center) = calibrationPhase {
            EyeWindowLog.info(
                "calibration: display 1 done — turn your head toward display 2 (dots 4–6)"
            )
        }
        if calibrationPhase.isRecording {
            EyeWindowLog.info(
                "calibration: \(calibrationFlow.stepLabel) dot \(calibrationFlow.currentStepIndex)/\(CalibrationFlow.totalSteps) (~\(Int(CalibrationFlow.minStepDuration))s)"
            )
        }
    }

    public nonisolated static func poseLabelUncalibrated(for pose: HeadPose) -> String? {
        guard pose.onDisplayAttention else { return "away" }
        if pose.yawRadians < -GazeStateMachine.yawThresholdRadians { return "L" }
        if pose.yawRadians > GazeStateMachine.yawThresholdRadians { return "R" }
        return "C"
    }
}
