import AppKit
import EyeWindowCore
import Foundation

/// Red-dot calibration smoke: 3 targets × 2 displays, pooled mean per screen.
enum InteractiveCalibrate {
    static let recordSeconds: TimeInterval = CalibrationFlow.minStepDuration

    static func run() {
        print("=== Gaze calibration smoke (nearest mean vector) ===\n")
        fflush(stdout)

        setupAppKit()

        let done = DispatchSemaphore(value: 0)
        var exitCode: Int32 = 1

        Task { @MainActor in
            var failed = false
            exitCode = await runCalibration(failed: &failed)
            done.signal()
        }

        pumpRunLoopUntil { done.wait(timeout: .now()) == .success }
        fflush(stdout)
        exit(exitCode)
    }

    private static func setupAppKit() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.activate(ignoringOtherApps: true)
    }

    /// CLI tools have no run loop by default — pump so AppKit windows and AsyncStream work.
    private static func pumpRunLoopUntil(_ condition: () -> Bool) {
        while !condition() {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }

    private static func runLoopFor(seconds: TimeInterval) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            RunLoop.main.run(mode: .default, before: min(end, Date().addingTimeInterval(0.05)))
        }
    }

    @MainActor
    private static func runCalibration(failed: inout Bool) async -> Int32 {
        guard case .dual(let layout) = DisplayMonitor.currentDisplays() else {
            print("  FAIL need exactly 2 displays connected")
            return 1
        }

        var status = GazeEngine.cameraPermissionStatus()
        if status == .notDetermined {
            print("→ Allow camera access when macOS prompts…")
            fflush(stdout)
            let granted = await GazeEngine.requestCameraAccess()
            status = granted ? .authorized : .denied
        }
        guard status == .authorized else {
            print("  FAIL camera permission denied (System Settings → Privacy → Camera)")
            return 1
        }

        let overlay = CalibrationOverlay()
        defer { overlay.hide() }

        let engine = GazeEngine()
        let collector = GazeSampleCollector()
        _ = engine.gazeStream()
        engine.setPoseHandler { pose in
            collector.append(pose)
        }

        do {
            try engine.start()
        } catch {
            print("  FAIL GazeEngine.start — \(error)")
            return 1
        }
        defer {
            engine.stop()
            engine.setPoseHandler(nil)
        }

        let perDisplay = Int(recordSeconds) * CalibrationFlow.targetsPerDisplay
        let total = Int(CalibrationFlow.estimatedTotalDuration)
        print(
            "Look at each red dot (\(CalibrationFlow.targetsPerDisplay) per display: center, left, right · ~\(perDisplay)s per screen · ~\(total)s total). Runtime: \(GazeVectorSmoother.windowSize)-frame mean → Mahalanobis nearest.\n"
        )
        fflush(stdout)
        runLoopFor(seconds: 0.4)
        fflush(stdout)

        var d1Samples: [GazeFeatureVector] = []
        var d2Samples: [GazeFeatureVector] = []
        var step = 0

        for display in [DisplayNumber.one, DisplayNumber.two] {
            let label = display == .one ? "DISPLAY 1" : "DISPLAY 2"
            var displaySamples: [GazeFeatureVector] = []

            for target in CalibrationFlow.targetSequence {
                step += 1
                if !recordTarget(
                    display: display,
                    target: target,
                    stepIndex: step,
                    layout: layout,
                    overlay: overlay,
                    label: label,
                    collector: collector,
                    into: &displaySamples,
                    failed: &failed
                ) { return 1 }
            }

            if display == .one {
                d1Samples = displaySamples
            } else {
                d2Samples = displaySamples
            }
        }

        overlay.hide()

        guard !failed else { return 1 }

        let refined = CalibrationQuality.refineSamples(
            display1: d1Samples,
            display2: d2Samples
        )
        let profile = CalibrationProfile.derive(
            display1Samples: d1Samples,
            display2Samples: d2Samples
        )
        let report = CalibrationQuality.evaluate(
            profile: profile,
            display1Samples: refined.display1,
            display2Samples: refined.display2
        )
        printSummary(profile: profile, report: report, d1: refined.display1, d2: refined.display2)

        guard report.passed else {
            print(
                "\n  FAIL calibration quality gate (need yaw ≥ \(String(format: "%.0f", CalibrationQuality.minYawGapRadians * 180 / .pi))°, gap ≥ \(CalibrationQuality.minVecSeparation), replay ≥ \(Int(CalibrationQuality.minReplayAccuracy * 100))%):"
            )
            for line in CalibrationQuality.failureLines(report) {
                print("    • \(line)")
            }
            print("")
            failed = true
            return 1
        }

        if CommandLine.arguments.contains("--save") {
            if CalibrationStore.shared.save(profile) {
                print("\nSaved to Application Support (Eye Window/calibration.json)")
            } else {
                print("\n  WARN could not save calibration.json")
            }
        } else {
            print("\nTip: pass --save to write calibration.json for the menu bar app")
        }

        print("\n=== PASS (calibration quality OK) ===")
        return 0
    }

    @MainActor
    private static func recordTarget(
        display: DisplayNumber,
        target: CalibrationTarget,
        stepIndex: Int,
        layout: DualLayout,
        overlay: CalibrationOverlay,
        label: String,
        collector: GazeSampleCollector,
        into out: inout [GazeFeatureVector],
        failed: inout Bool
    ) -> Bool {
        guard let frame = DisplayMonitor.screenFrame(for: display, layout: layout) else {
            print("  FAIL no screen frame for \(label)")
            failed = true
            return false
        }

        collector.reset()
        let center = target.dotCenter(inScreenFrame: frame)
        overlay.showDot(at: center)

        print(
            "→ [\(stepIndex)/\(CalibrationFlow.totalSteps)] Look at RED DOT on \(label) (\(target.label)) (\(Int(recordSeconds)) s) …"
        )
        fflush(stdout)

        runLoopFor(seconds: recordSeconds)
        overlay.hide()

        let features = CalibrationQuality.trimInitialFrames(
            collector.samples.map(GazeFeatureVector.fromPose)
        )
        out.append(contentsOf: features)

        let minFrames = max(20, CalibrationFlow.minSamplesPerStep / 2)
        guard features.count >= minFrames else {
            print(
                "  FAIL \(label) \(target.label): only \(features.count) gaze frames — stay in front of webcam (model uses center crop of image)\n"
            )
            failed = true
            return false
        }

        let mean = GazeFeatureVector.mean(features)
        let spread = GazeFeatureSpread.fromSamples(features)
        print(
            "  \(label) \(target.label): \(features.count) frames — mean vec=(\(fmt(mean.gx)),\(fmt(mean.gy)),\(fmt(mean.gz))) yaw=\(fmt(mean.yawRadians)) std max=\(fmt(spread.maxComponent))\n"
        )
        fflush(stdout)
        return true
    }

    private static func printSummary(
        profile: CalibrationProfile,
        report: CalibrationQuality.Report,
        d1: [GazeFeatureVector],
        d2: [GazeFeatureVector]
    ) {
        let d1m = profile.display1
        let d2m = profile.display2
        let s1 = profile.display1Spread
        let s2 = profile.display2Spread

        print("--- Mean 5D vector per display (all targets pooled, stable frames only) ---")
        print(
            "  D1  vec=(\(fmt(d1m.gx)),\(fmt(d1m.gy)),\(fmt(d1m.gz)))  yaw=\(fmt(d1m.yawRadians))  pitch=\(fmt(d1m.pitchRadians))"
        )
        print(
            "  D2  vec=(\(fmt(d2m.gx)),\(fmt(d2m.gy)),\(fmt(d2m.gz)))  yaw=\(fmt(d2m.yawRadians))  pitch=\(fmt(d2m.pitchRadians))"
        )
        print("  D1 std  gx=\(fmt(s1.gx)) gy=\(fmt(s1.gy)) gz=\(fmt(s1.gz)) yaw=\(fmt(s1.yawRadians)) pitch=\(fmt(s1.pitchRadians))")
        print("  D2 std  gx=\(fmt(s2.gx)) gy=\(fmt(s2.gy)) gz=\(fmt(s2.gz)) yaw=\(fmt(s2.yawRadians)) pitch=\(fmt(s2.pitchRadians))")
        let minYawDeg = CalibrationQuality.minYawGapRadians * 180 / .pi
        print(
            "  5D gap=\(fmt(report.vecGap)) (need ≥\(fmt(CalibrationQuality.minVecSeparation)))   gx gap=\(fmt(report.gxGap))   yaw=\(fmt(report.yawGapRadians * 180 / .pi))° (need ≥\(fmt(minYawDeg))°)"
        )
        print(
            "  pooled frames: D1=\(report.display1FramesUsed) D2=\(report.display2FramesUsed) (~\(CalibrationQuality.initialFramesDroppedPerStep) initial frames dropped per dot)"
        )
        let pct = Int((report.replayAccuracy * 100).rounded())
        let yawPct = Int((report.yawReplayAccuracy * 100).rounded())
        print(
            "\n--- Mahalanobis nearest mean (\(GazeVectorSmoother.windowSize)-frame rolling mean at runtime) ---"
        )
        print("  5D replay \(report.replayCorrect)/\(report.replayTotal) (\(pct)%)")
        print(
            "  yaw-only replay \(report.yawReplayCorrect)/\(report.replayTotal) (\(yawPct)%) — nearest prototype by yaw alone"
        )
        if report.passed {
            print("  OK quality gate passed")
        }
        fflush(stdout)
    }

    private static func fmt(_ x: Double) -> String {
        String(format: "%.4f", x)
    }
}

/// Thread-safe buffer for gaze samples from `GazeEngine` (AVCapture runs off main).
private final class GazeSampleCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [HeadPose] = []

    func reset() {
        lock.lock()
        stored = []
        lock.unlock()
    }

    func append(_ pose: HeadPose) {
        guard pose.isValidGazeSample else { return }
        lock.lock()
        stored.append(pose)
        lock.unlock()
    }

    var samples: [HeadPose] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}
