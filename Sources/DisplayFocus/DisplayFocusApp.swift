import AppKit
import SwiftUI
import DisplayFocusCore

@main
struct DisplayFocusApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            menuContent
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "eye")
            if let progress = menuBarProgressFraction(model.coordinator) {
                Text(progress)
                    .font(.caption2)
            }
        }
    }

    private func menuBarProgressFraction(_ coordinator: SessionCoordinator) -> String? {
        let interval = coordinator.blinkBreakInterval
        guard interval > 0 else { return nil }
        let elapsed = coordinator.blinkAccumulatedSeconds
        if interval < 60 {
            let num = max(0, Int(elapsed.rounded(.down)))
            let den = max(1, Int(interval.rounded()))
            return "\(num)/\(den)"
        }
        let num = max(0, Int((elapsed / 60).rounded(.down)))
        let den = max(1, Int((interval / 60).rounded()))
        return "\(num)/\(den)"
    }

    private func formatDuration(_ seconds: TimeInterval, roundUp: Bool = false) -> String {
        if seconds < 60 {
            let secs = max(0, Int((roundUp ? ceil(seconds) : seconds.rounded(.down))))
            return secs == 1 ? "1s" : "\(secs)s"
        }
        let totalMinutes = max(0, Int((roundUp ? ceil(seconds / 60) : (seconds / 60).rounded(.down))))
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 { return "\(hours)h" }
            return "\(hours)h \(minutes)m"
        }
        return totalMinutes == 1 ? "1m" : "\(totalMinutes)m"
    }

    @ViewBuilder
    private var menuContent: some View {
        let coordinator = model.coordinator
        let blinkDisabled = coordinator.blinkBreakTriggered

        Text(blinkReminderStatus(coordinator))
            .font(.caption)
            .foregroundStyle(blinkReminderColor(coordinator))

        Picker("Tracking mode", selection: Binding(
            get: { coordinator.blinkTrackingMode },
            set: { model.setBlinkTrackingMode($0) }
        )) {
            ForEach(BlinkTrackingMode.allCases, id: \.self) { mode in
                Text(mode.menuLabel).tag(mode)
            }
        }
        .disabled(blinkDisabled)

        Picker("Break interval", selection: Binding(
            get: { coordinator.blinkBreakInterval },
            set: { model.setBlinkBreakInterval($0) }
        )) {
            ForEach(BlinkBreakIntervalPreset.allCases) { preset in
                Text(preset.menuLabel).tag(preset.breakInterval)
            }
        }
        .disabled(blinkDisabled)

        Button(coordinator.blinkRemindersPaused ? "Resume blink reminders" : "Pause blink reminders") {
            model.setBlinkRemindersPaused(!coordinator.blinkRemindersPaused)
        }
        .disabled(blinkDisabled)

        if !coordinator.recentLogLines.isEmpty {
            Divider()
            ForEach(Array(coordinator.recentLogLines.suffix(4).enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
        }

        Divider()

        Toggle("Open at login", isOn: Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { model.setLaunchAtLogin($0) }
        ))

        if case .dual = coordinator.displayLayout {
            Button("Focus display 1 (⌘⌥1)") { model.focus(.one) }
            Button("Focus display 2 (⌘⌥2)") { model.focus(.two) }
            Divider()
        }

        Button("Quit") { NSApplication.shared.terminate(nil) }
    }

    private func blinkReminderStatus(_ coordinator: SessionCoordinator) -> String {
        let status: String
        if coordinator.blinkRemindersPaused {
            status = "paused"
        } else if coordinator.blinkTrackingMode == .activity, coordinator.blinkIsIdle {
            status = "idle"
        } else {
            status = "running"
        }
        let elapsed = formatDuration(coordinator.blinkAccumulatedSeconds)
        let remaining = formatDuration(coordinator.blinkSecondsUntilBreak, roundUp: true)
        return "Blink reminders: \(status) · Elapsed: \(elapsed) · Remaining: \(remaining)"
    }

    private func blinkReminderColor(_ coordinator: SessionCoordinator) -> Color {
        if coordinator.blinkRemindersPaused { return .secondary }
        if coordinator.blinkTrackingMode == .activity, coordinator.blinkIsIdle { return .orange }
        return .secondary
    }
}
