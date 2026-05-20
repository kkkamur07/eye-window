import Foundation

@MainActor
public final class SessionCoordinator: ObservableObject {
    @Published public private(set) var displayLayout: DisplayLayout = .notDual
    @Published public private(set) var isAccessibilityBlocked = false
    @Published public private(set) var currentFocusDisplay: DisplayNumber?
    @Published public private(set) var activeAppName: String?
    @Published public private(set) var recentLogLines: [String] = []

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
}
