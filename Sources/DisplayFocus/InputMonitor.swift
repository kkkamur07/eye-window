import AppKit
import ApplicationServices
import DisplayFocusCore

/// Global keyboard, mouse, and scroll listeners for **Active usage time** tracking.
///
/// Requires **Input Monitoring** permission. `start()` only registers listeners when
/// permission is already granted; prompting is handled by `InputMonitoringAccess`.
@MainActor
final class InputMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var didLogFirstActivity = false
    var onActivity: (() -> Void)?

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        guard InputMonitoringAccess.isGranted else {
            return false
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: Self.eventMask,
            callback: inputMonitorEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        Log.info("input monitor started")
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        didLogFirstActivity = false
    }

    fileprivate func handleActivity(rawType: UInt32) {
        if !didLogFirstActivity {
            didLogFirstActivity = true
            Log.info("input monitor activity detected type=\(rawType)")
        }
        onActivity?()
    }

    fileprivate func reenableEventTap() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        Log.info("input monitor event tap re-enabled")
    }

    private static let eventMask: CGEventMask = makeEventMask([
        CGEventType.keyDown,
        CGEventType.flagsChanged,
        CGEventType.leftMouseDown,
        CGEventType.rightMouseDown,
        CGEventType.otherMouseDown,
        CGEventType.mouseMoved,
        CGEventType.leftMouseDragged,
        CGEventType.rightMouseDragged,
        CGEventType.otherMouseDragged,
        CGEventType.scrollWheel,
    ])

    private static func makeEventMask(_ types: [CGEventType]) -> CGEventMask {
        var mask = CGEventMask(0)
        for type in types {
            mask |= CGEventMask(1 << type.rawValue)
        }
        return mask
    }
}

private func inputMonitorEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let monitor = Unmanaged<InputMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    let rawType = type.rawValue

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        Task { @MainActor in monitor.reenableEventTap() }
        return Unmanaged.passUnretained(event)
    }

    Task { @MainActor in monitor.handleActivity(rawType: rawType) }
    return Unmanaged.passUnretained(event)
}
