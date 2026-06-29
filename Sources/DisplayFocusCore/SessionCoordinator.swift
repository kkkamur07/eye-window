import Foundation

@MainActor
public final class SessionCoordinator: ObservableObject {
    @Published public private(set) var displayLayout: DisplayLayout = .notDual
    @Published public private(set) var isAccessibilityBlocked = false
    @Published public private(set) var isInputMonitoringBlocked = false
    @Published public private(set) var currentFocusDisplay: DisplayNumber?
    @Published public private(set) var activeAppName: String?
    @Published public private(set) var activeAppBundleId: String?
    @Published public private(set) var recentLogLines: [String] = []
    @Published public private(set) var blinkAccumulatedSeconds: TimeInterval = 0
    @Published public private(set) var blinkSecondsUntilBreak: TimeInterval = ActiveUsageConfiguration.default.breakInterval
    @Published public private(set) var blinkBreakInterval: TimeInterval = ActiveUsageConfiguration.default.breakInterval
    @Published public private(set) var blinkIsIdle = false
    @Published public private(set) var blinkRemindersPaused = false
    @Published public private(set) var blinkBreakTriggered = false
    @Published public private(set) var blinkTrackingMode: BlinkTrackingMode = .clock

    public let focusHistory = FocusHistory()

    public init() {
        Log.onLine = { [weak self] line in
            Task { @MainActor in self?.appendLogLine(line) }
        }
        refreshDisplayLayout()
    }

    public func refreshDisplayLayout() {
        displayLayout = DisplayMonitor.currentDisplays()
    }

    public func setFocus(display: DisplayNumber, appName: String?, bundleId: String? = nil) {
        currentFocusDisplay = display
        activeAppName = appName
        activeAppBundleId = bundleId
    }

    public func setAccessibilityBlocked(_ blocked: Bool) {
        isAccessibilityBlocked = blocked
    }

    public func setInputMonitoringBlocked(_ blocked: Bool) {
        isInputMonitoringBlocked = blocked
    }

    public func setBlinkTrackingMode(_ mode: BlinkTrackingMode) {
        blinkTrackingMode = mode
    }

    public func updateBlinkReminderState(
        accumulatedSeconds: TimeInterval,
        secondsUntilBreak: TimeInterval,
        breakInterval: TimeInterval,
        isIdle: Bool,
        remindersPaused: Bool,
        breakTriggered: Bool
    ) {
        blinkAccumulatedSeconds = accumulatedSeconds
        blinkSecondsUntilBreak = secondsUntilBreak
        blinkBreakInterval = breakInterval
        blinkIsIdle = isIdle
        blinkRemindersPaused = remindersPaused
        blinkBreakTriggered = breakTriggered
    }

    private func appendLogLine(_ line: String) {
        recentLogLines.append(line)
        if recentLogLines.count > 16 {
            recentLogLines.removeFirst(recentLogLines.count - 16)
        }
    }
}
