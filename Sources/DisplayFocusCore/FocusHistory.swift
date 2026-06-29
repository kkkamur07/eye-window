/// Identifies an application for focus tracking (MVP: bundle identifier only).
public struct AppRef: Hashable, Sendable, Equatable {
    public let bundleIdentifier: String

    public init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
    }
}

/// Result of computing the next app for **Rotate**.
public enum RotateTarget: Equatable, Sendable {
    /// Next app in the **Focus stack** (wraps from bottom to top).
    case next(AppRef)
    /// Stack has at most one app, or current app is not in the stack.
    case noOp
}

/// Session-scoped **Focus stack** per **Display**. Not persisted across restarts.
public final class FocusHistory {
    private var stacksByDisplay: [DisplayNumber: [AppRef]] = [:]

    public init() {}

    public func recordFocusChange(app: AppRef, display: DisplayNumber) {
        var stack = stacksByDisplay[display] ?? []
        stack.removeAll { $0 == app }
        stack.insert(app, at: 0)
        stacksByDisplay[display] = stack
    }

    /// Ordered most-recent-first **Focus stack** for a **Display**.
    public func stack(for display: DisplayNumber) -> [AppRef] {
        stacksByDisplay[display] ?? []
    }

    /// Top of the **Focus stack** — same as **Last-focused app**.
    public func lastFocused(display: DisplayNumber) -> AppRef? {
        stack(for: display).first
    }

    /// Eager prune: drop an app from every **Focus stack** when it quits.
    public func remove(app: AppRef) {
        for display in stacksByDisplay.keys {
            stacksByDisplay[display]?.removeAll { $0 == app }
        }
    }

    /// Next app for **Rotate** after `currentApp`, wrapping to the top of the stack.
    public func nextForRotate(display: DisplayNumber, currentApp: AppRef) -> RotateTarget {
        let stack = stack(for: display)
        guard stack.count > 1 else { return .noOp }
        guard let index = stack.firstIndex(of: currentApp) else { return .noOp }
        let nextIndex = (index + 1) % stack.count
        return .next(stack[nextIndex])
    }

    public func reset() {
        stacksByDisplay.removeAll()
    }
}
