import SwiftUI
import EyeWindowCore

@main
struct EyeWindowApp: App {
    @StateObject private var coordinator = SessionCoordinator()
    @State private var focusObserver: FocusObserver?
    @State private var mouseClickCollector: MouseClickLabelCollector?
    @State private var hotkeyService: HotkeyService?
    @State private var calibrationDotPresenter = CalibrationDotPresenter()

    var body: some Scene {
        MenuBarExtra(statusTitle(coordinator), systemImage: "eye") {
            menuContent(coordinator)
                .onAppear {
                    coordinator.calibrationDotPresenter = calibrationDotPresenter
                    coordinator.onFocusIntent = { display in
                        activateFocus(display: display, coordinator: coordinator, source: "gaze")
                    }
                    if hotkeyService == nil {
                        let service = HotkeyService { coordinator.toggleGazePause() }
                        service.start()
                        hotkeyService = service
                    }
                }
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: coordinator.isSessionActive) { isActive in
            syncImplicitCollectors(isActive: isActive, layout: coordinator.displayLayout)
        }
        .onChange(of: coordinator.displayLayout) { layout in
            syncImplicitCollectors(isActive: coordinator.isSessionActive, layout: layout)
        }
    }

    private func syncImplicitCollectors(isActive: Bool, layout: DisplayLayout) {
        if isActive, case .dual = layout {
            if focusObserver == nil {
                let observer = FocusObserver(history: coordinator.focusHistory)
                observer.onFocusRecorded = { display, appName in
                    coordinator.setFocus(display: display, appName: appName)
                    coordinator.recordImplicitAppFocus(display: display)
                }
                observer.start()
                focusObserver = observer
            }
            if mouseClickCollector == nil {
                let collector = MouseClickLabelCollector()
                collector.onClick = { point in
                    coordinator.recordImplicitMouseClick(at: point)
                }
                collector.start()
                mouseClickCollector = collector
            }
        } else {
            focusObserver?.stop()
            focusObserver = nil
            mouseClickCollector?.stop()
            mouseClickCollector = nil
        }
    }

    private func statusTitle(_ coordinator: SessionCoordinator) -> String {
        guard coordinator.isSessionActive else { return "Eye Window · Off" }
        if let cal = calibrationStatusShort(coordinator) { return cal }
        if coordinator.isGazePaused { return "Eye Window · P" }

        var parts: [String] = []
        if let display = coordinator.currentFocusDisplay {
            parts.append("D\(display.rawValue)")
        }
        if let app = coordinator.activeAppName {
            parts.append(shortName(app))
        }
        if !parts.isEmpty {
            return "Eye Window · " + parts.joined(separator: " ")
        }
        return "Eye Window · On"
    }

    private func shortName(_ name: String) -> String {
        if name.count <= 14 { return name }
        return String(name.prefix(13)) + "…"
    }

    private func calibrationStatusShort(_ coordinator: SessionCoordinator) -> String? {
        guard coordinator.calibrationPhase.isRecording else { return nil }
        if case .lookAt(let display, _) = coordinator.calibrationPhase {
            return "Eye Window · Cal D\(display.rawValue)"
        }
        return nil
    }

    private func calibrationMenuText(_ coordinator: SessionCoordinator) -> String? {
        if case .lookAt(let display, let target) = coordinator.calibrationPhase {
            let n = coordinator.calibrationSampleProgress
            return "Calibration: D\(display.rawValue) \(target.label) (\(n)/\(CalibrationFlow.minSamplesPerStep)+)"
        }
        switch coordinator.calibrationPhase {
        case .lookAt:
            return nil
        case .complete, .idle:
            guard coordinator.isSessionActive else { return nil }
            if coordinator.calibrationNeedsAttention {
                return "Calibration failed — use Recalibrate"
            }
            if coordinator.isCalibrated {
                return "Calibration: ready"
            }
            if !coordinator.isCameraBlocked {
                return "Calibration: pending"
            }
            return nil
        }
    }

    private func displayStatusText(_ layout: DisplayLayout) -> String {
        switch layout {
        case .dual(let dual):
            return dual.display1IsLeft ? "Dual: 1 left" : "Dual: 1 right"
        case .notDual:
            return "Need exactly 2 displays"
        }
    }

    private func displayStatusColor(_ layout: DisplayLayout) -> Color {
        switch layout {
        case .dual:
            return .primary
        case .notDual:
            return .orange
        }
    }

    @ViewBuilder
    private func gazeMenuReadout(_ coordinator: SessionCoordinator) -> some View {
        if !coordinator.hasLiveGazeFrames {
            Text("Gaze: waiting for webcam…")
                .font(.caption)
                .foregroundStyle(Color.orange)
        } else if let label = coordinator.latestPoseLabel,
                  let gx = coordinator.latestGx,
                  let gy = coordinator.latestGy,
                  let gz = coordinator.latestGz
        {
            let yaw = coordinator.latestYawRadians.map { String(format: "%.2f", $0) } ?? "—"
            Text(
                "Gaze: \(label) · vec (\(String(format: "%.2f", gx)),\(String(format: "%.2f", gy)),\(String(format: "%.2f", gz))) yaw \(yaw)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func gazeStatusText(_ coordinator: SessionCoordinator) -> String? {
        guard coordinator.isSessionActive, !coordinator.isGazePaused else { return nil }
        guard let status = coordinator.gazeStatus else { return nil }

        if let candidate = status.candidateDisplay, status.dwellProgress > 0 {
            let pct = Int(status.dwellProgress * 100)
            return "Dwelling D\(candidate.rawValue) \(pct)%"
        }
        if let mapped = status.mappedDisplay {
            return "Looking D\(mapped.rawValue) (\(status.stableFrameCount)/\(GazeStateMachine.requiredStableFrames))"
        }
        if status.onAttention {
            return "Looking center"
        }
        return "Away from displays"
    }

    private var focusDebugEnabled: Bool {
        guard coordinator.isSessionActive else { return false }
        guard case .dual = coordinator.displayLayout else { return false }
        return FocusController.isAccessibilityGranted()
    }

    private func activateFocus(
        display: DisplayNumber,
        coordinator: SessionCoordinator,
        source: String
    ) {
        guard case .dual(let layout) = coordinator.displayLayout else { return }
        let result = FocusController.activate(
            display: display,
            history: coordinator.focusHistory,
            layout: layout
        )
        switch result {
        case .accessibilityDenied:
            coordinator.setAccessibilityBlocked(true)
            EyeWindowLog.info("focus D\(display.rawValue) blocked (accessibility)")
        case .activated(let appName):
            coordinator.setAccessibilityBlocked(false)
            coordinator.setFocus(display: display, appName: appName)
            let appPart = appName.map { " → \($0)" } ?? ""
            EyeWindowLog.info("focus OK \(source) D\(display.rawValue)\(appPart)")
        case .notDual:
            EyeWindowLog.info("focus FAIL \(source) D\(display.rawValue): not dual")
        case .noAppFound:
            EyeWindowLog.info("focus FAIL \(source) D\(display.rawValue): no app (click target display once)")
        }
    }

    @ViewBuilder
    private func menuContent(_ coordinator: SessionCoordinator) -> some View {
        Text(coordinator.isSessionActive ? "Session active" : "Session inactive")
            .font(.caption)

        if coordinator.isSessionActive {
            if let display = coordinator.currentFocusDisplay {
                let app = coordinator.activeAppName ?? "Unknown app"
                Text("Focus: D\(display.rawValue) · \(app)")
                    .font(.caption)
            } else {
                Text("Focus: not set")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(coordinator.isGazePaused ? "Gaze paused" : "Gaze active")
                .font(.caption)
                .foregroundStyle(coordinator.isGazePaused ? .orange : .secondary)

            if let calLine = calibrationMenuText(coordinator) {
                Text(calLine)
                    .font(.caption)
                    .foregroundStyle(
                        coordinator.calibrationPhase.isRecording
                            ? .orange : .secondary
                    )
            }
            Text(displayStatusText(coordinator.displayLayout))
                .font(.caption)
                .foregroundStyle(displayStatusColor(coordinator.displayLayout))

            if coordinator.isCameraBlocked {
                Text("Camera blocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !coordinator.isGazePaused {
                gazeMenuReadout(coordinator)
                if let gazeLine = gazeStatusText(coordinator) {
                    Text(gazeLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if coordinator.isAccessibilityBlocked {
                Text("Accessibility blocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !coordinator.isCameraBlocked, !coordinator.isGazePaused {
                let s = coordinator.implicitDatasetStats
                Text("Learning: \(s.total) samples (D1 \(s.display1) · D2 \(s.display2))")
                    .font(.caption)
                    .foregroundStyle(s.total > 0 ? .primary : .secondary)
            }

            if !coordinator.recentLogLines.isEmpty {
                Divider()
                Text("Recent log")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(Array(coordinator.recentLogLines.suffix(6).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }

        Divider()

        Button("Start session") {
            coordinator.calibrationDotPresenter = calibrationDotPresenter
            coordinator.startSession()
        }
        .disabled(coordinator.isSessionActive)

        Button("Stop session") {
            coordinator.stopSession()
        }
        .disabled(!coordinator.isSessionActive)

        Button("Recalibrate") {
            coordinator.calibrationDotPresenter = calibrationDotPresenter
            coordinator.recalibrate()
        }
        .disabled(!coordinator.isSessionActive || coordinator.isCameraBlocked)

        Button("Clear learning data") {
            coordinator.clearImplicitDataset()
        }
        .disabled(!coordinator.isSessionActive)

        if focusDebugEnabled {
            Divider()

            Button("Focus display 1") {
                activateFocus(display: .one, coordinator: coordinator, source: "manual")
            }

            Button("Focus display 2") {
                activateFocus(display: .two, coordinator: coordinator, source: "manual")
            }
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
