import SwiftUI
import DisplayFocusCore

@main
struct DisplayFocusApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra(statusTitle(model.coordinator), systemImage: "rectangle.on.rectangle") {
            menuContent
        }
        .menuBarExtraStyle(.menu)
    }

    private func statusTitle(_ coordinator: SessionCoordinator) -> String {
        var parts: [String] = []
        if let display = coordinator.currentFocusDisplay {
            parts.append("D\(display.rawValue)")
        }
        if let app = coordinator.activeAppName {
            parts.append(shortName(app))
        }
        if parts.isEmpty { return "Display Focus" }
        return "Display Focus · " + parts.joined(separator: " ")
    }

    private func shortName(_ name: String) -> String {
        name.count <= 14 ? name : String(name.prefix(13)) + "…"
    }

    @ViewBuilder
    private var menuContent: some View {
        let coordinator = model.coordinator

        if let display = coordinator.currentFocusDisplay {
            Text("Focus: D\(display.rawValue) · \(coordinator.activeAppName ?? "—")")
                .font(.caption)
        } else {
            Text("Focus: unknown").font(.caption).foregroundStyle(.secondary)
        }

        Text(coordinator.displayLayout == .notDual ? "Connect exactly 2 displays" : "Dual displays · hotkeys active")
            .font(.caption)
            .foregroundStyle(coordinator.displayLayout == .notDual ? .orange : .secondary)

        if coordinator.isAccessibilityBlocked {
            Text("Accessibility required").font(.caption).foregroundStyle(.orange)
        }

        Text("⌘⌥1 → display 1   ⌘⌥2 → display 2")
            .font(.caption2)
            .foregroundStyle(.secondary)

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
}
