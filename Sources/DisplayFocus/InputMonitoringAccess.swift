import AppKit
import ApplicationServices

/// **Input Monitoring** permission for global keyboard/mouse/scroll events (blink reminders).
///
/// Uses `CGRequestListenEventAccess` (not Accessibility). macOS shows at most one TCC prompt
/// at a time, so callers should request this before the Accessibility prompt.
enum InputMonitoringAccess {
    static var isGranted: Bool {
        CGPreflightListenEventAccess()
    }

    /// Prompts on first call when status is undetermined. Safe to call from a menu button (user action).
    @discardableResult
    static func requestIfNeeded() -> Bool {
        if CGPreflightListenEventAccess() { return true }
        let prompted = CGRequestListenEventAccess()
        if CGPreflightListenEventAccess() { return true }
        // Creating a listen-only tap registers the app in the Input Monitoring list on some macOS versions.
        _ = registerListenOnlyTap()
        return prompted && CGPreflightListenEventAccess()
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @discardableResult
    private static func registerListenOnlyTap() -> Bool {
        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.leftMouseDown.rawValue)
                | (1 << CGEventType.scrollWheel.rawValue)
        )
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: listenOnlyTapCallback,
            userInfo: nil
        ) else {
            return false
        }
        CGEvent.tapEnable(tap: tap, enable: false)
        return true
    }
}

private func listenOnlyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    Unmanaged.passUnretained(event)
}
