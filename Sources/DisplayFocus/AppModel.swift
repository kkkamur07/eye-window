import AppKit
import DisplayFocusCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let coordinator = SessionCoordinator()
    private var focusObserver: FocusObserver?
    private var hotkeyService: HotkeyService?
    private var screenObserver: NSObjectProtocol?

    init() {
        bootstrap()
    }

    func bootstrap() {
        coordinator.refreshDisplayLayout()
        FocusController.requestAccessibilityIfNeeded()
        startHotkeys()
        startFocusObserverIfNeeded()
        LaunchAtLogin.applyOnLaunch()
        watchDisplays()
        Log.info("ready (⌘⌥1 · ⌘⌥2)")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        LaunchAtLogin.isEnabled = enabled
        Log.info(enabled ? "open at login: on" : "open at login: off")
    }

    func focus(_ display: DisplayNumber) {
        coordinator.refreshDisplayLayout()
        let result = FocusController.activate(display: display, history: coordinator.focusHistory)
        switch result {
        case .accessibilityDenied:
            coordinator.setAccessibilityBlocked(true)
            Log.info("D\(display.rawValue): allow Accessibility in System Settings")
        case .activated(let appName):
            coordinator.setAccessibilityBlocked(false)
            coordinator.setFocus(display: display, appName: appName)
            let appPart = appName.map { " → \($0)" } ?? ""
            Log.info("D\(display.rawValue)\(appPart)")
        case .notDual:
            Log.info("D\(display.rawValue): connect exactly 2 displays")
        case .noAppFound:
            Log.info("D\(display.rawValue): click an app on that display once")
        }
    }

    private func startHotkeys() {
        guard hotkeyService == nil else { return }
        let service = HotkeyService(handlers: [
            .focusDisplay1: { [weak self] in self?.focus(.one) },
            .focusDisplay2: { [weak self] in self?.focus(.two) },
        ])
        service.start()
        hotkeyService = service
    }

    private func startFocusObserverIfNeeded() {
        coordinator.refreshDisplayLayout()
        guard case .dual = coordinator.displayLayout else {
            focusObserver?.stop()
            focusObserver = nil
            return
        }
        guard focusObserver == nil else { return }
        let observer = FocusObserver(history: coordinator.focusHistory)
        observer.onFocusRecorded = { [weak self] display, appName in
            self?.coordinator.setFocus(display: display, appName: appName)
        }
        observer.start()
        focusObserver = observer
        Log.info("focus tracking on")
    }

    private func watchDisplays() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.coordinator.refreshDisplayLayout()
                self?.startFocusObserverIfNeeded()
            }
        }
    }
}
