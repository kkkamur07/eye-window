import AppKit
import Combine
import DisplayFocusCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let coordinator = SessionCoordinator()
    private var focusObserver: FocusObserver?
    private var hotkeyService: HotkeyService?
    private var screenObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var blinkCoordinator: BlinkReminderCoordinator?
    private let blinkOverlay = BlinkOverlayController()
    private var blinkBreakCancellable: AnyCancellable?
    private var coordinatorCancellable: AnyCancellable?
    private var inputMonitor: InputMonitor?

    init() {
        coordinatorCancellable = coordinator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        bootstrap()
    }

    func bootstrap() {
        coordinator.refreshDisplayLayout()
        startHotkeys()
        startFocusObserverIfNeeded()
        LaunchAtLogin.applyOnLaunch()
        watchDisplays()
        watchAppTermination()
        startBlinkReminders()
        Log.info("ready (⌘⌥1 · ⌘⌥2)")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        LaunchAtLogin.isEnabled = enabled
        Log.info(enabled ? "open at login: on" : "open at login: off")
    }

    func setBlinkRemindersPaused(_ paused: Bool) {
        blinkCoordinator?.setPaused(paused)
    }

    func setBlinkBreakInterval(_ interval: TimeInterval) {
        blinkCoordinator?.setBreakInterval(interval)
    }

    func setBlinkTrackingMode(_ mode: BlinkTrackingMode) {
        blinkCoordinator?.setTrackingMode(mode)
        syncInputMonitorForTrackingMode()
    }

    func focus(_ display: DisplayNumber) {
        coordinator.refreshDisplayLayout()
        let result = FocusController.activate(
            display: display,
            history: coordinator.focusHistory,
            currentFocusDisplay: coordinator.currentFocusDisplay,
            currentAppBundleId: coordinator.activeAppBundleId
        )
        switch result {
        case .accessibilityDenied:
            coordinator.setAccessibilityBlocked(true)
            Log.info("D\(display.rawValue): allow Accessibility in System Settings")
        case .activated(let appName):
            coordinator.setAccessibilityBlocked(false)
            coordinator.setFocus(
                display: display,
                appName: appName,
                bundleId: coordinator.focusHistory.lastFocused(display: display)?.bundleIdentifier
            )
            let appPart = appName.map { " → \($0)" } ?? ""
            Log.info("D\(display.rawValue)\(appPart)")
        case .notDual:
            Log.info("D\(display.rawValue): connect exactly 2 displays")
        case .noAppFound:
            Log.info("D\(display.rawValue): click an app on that display once")
        case .noOp:
            break
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
        observer.onFocusRecorded = { [weak self] display, appName, bundleId in
            self?.coordinator.setFocus(display: display, appName: appName, bundleId: bundleId)
        }
        observer.start()
        focusObserver = observer
        Log.info("focus tracking on")
    }

    private func startBlinkReminders() {
        let blinkCoordinator = BlinkReminderCoordinator(session: self.coordinator)
        blinkCoordinator.start()
        self.blinkCoordinator = blinkCoordinator

        blinkBreakCancellable = self.coordinator.$blinkBreakTriggered
            .removeDuplicates()
            .sink { [weak self] triggered in
                guard let self, triggered else { return }
                self.blinkOverlay.present { [weak self] reason in
                    self?.blinkCoordinator?.completeBreak()
                    if case .timerElapsed = reason {
                        Log.info("blink time: overlay ended")
                    }
                }
            }

        Log.info("blink reminders on")
        syncInputMonitorForTrackingMode()
    }

    private func syncInputMonitorForTrackingMode() {
        guard let blinkCoordinator else { return }

        switch blinkCoordinator.currentTrackingMode {
        case .clock:
            inputMonitor?.stop()
            inputMonitor = nil
            coordinator.setInputMonitoringBlocked(false)
        case .activity:
            let monitor = inputMonitor ?? makeInputMonitor()
            inputMonitor = monitor
            let started = monitor.start()
            coordinator.setInputMonitoringBlocked(!started)
        }
    }

    private func makeInputMonitor() -> InputMonitor {
        let monitor = InputMonitor()
        monitor.onActivity = { [weak self] in
            self?.blinkCoordinator?.recordActivity()
        }
        return monitor
    }

    private func watchAppTermination() {
        terminateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      let bundleId = app.bundleIdentifier
                else { return }
                self?.coordinator.focusHistory.remove(app: AppRef(bundleIdentifier: bundleId))
            }
        }
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
