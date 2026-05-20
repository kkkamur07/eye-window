/// Identifies an application for focus tracking (MVP: bundle identifier only).
public struct AppRef: Hashable, Sendable, Equatable {
    public let bundleIdentifier: String

    public init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
    }
}

/// Session-scoped last-focused app per display. Not persisted across restarts.
public final class FocusHistory {
    private var byDisplay: [DisplayNumber: AppRef] = [:]

    public init() {}

    public func recordFocusChange(app: AppRef, display: DisplayNumber) {
        byDisplay[display] = app
    }

    public func lastFocused(display: DisplayNumber) -> AppRef? {
        byDisplay[display]
    }

    public func reset() {
        byDisplay.removeAll()
    }
}
