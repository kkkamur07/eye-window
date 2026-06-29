import AppKit
import ApplicationServices
import CoreGraphics
import DisplayFocusCore

enum FocusActivationResult {
    case activated(appName: String?)
    case notDual
    case accessibilityDenied
    case noAppFound
    case noOp
}

@MainActor
enum FocusController {
    private static var hasRequestedAccessibility = false

    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityIfNeeded() {
        guard !hasRequestedAccessibility else { return }
        hasRequestedAccessibility = true
        guard !AXIsProcessTrusted() else { return }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func activate(
        display: DisplayNumber,
        history: FocusHistory,
        currentFocusDisplay: DisplayNumber?,
        currentAppBundleId: String?
    ) -> FocusActivationResult {
        guard DisplayMonitor.currentDisplays() != .notDual else { return .notDual }

        requestAccessibilityIfNeeded()
        guard isAccessibilityGranted() else {
            return .accessibilityDenied
        }

        guard let bounds = DisplayMonitor.dualDisplayBounds() else {
            return .notDual
        }

        if currentFocusDisplay == display {
            let stack = history.stack(for: display)
            if stack.count <= 1 {
                Log.info("D\(display.rawValue): only one app")
                return .noOp
            }
            let currentBundle = currentAppBundleId ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            if let currentBundle {
                let current = AppRef(bundleIdentifier: currentBundle)
                if case .next(let nextApp) = history.nextForRotate(display: display, currentApp: current),
                   let result = activateBundleId(nextApp.bundleIdentifier, display: display, history: history) {
                    return result
                }
            }
        }

        var candidates: [String] = []
        if let lastFocused = history.lastFocused(display: display)?.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: lastFocused).first != nil {
            candidates.append(lastFocused)
        }
        if let front = frontmostBundleId(
            on: display,
            display1Frame: bounds.display1,
            display2Frame: bounds.display2
        ) {
            candidates.append(front)
        }
        if let any = anyRegularBundleId(
            on: display,
            display1Frame: bounds.display1,
            display2Frame: bounds.display2
        ) {
            candidates.append(any)
        }
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.activationPolicy == .regular,
           let bundleId = frontmost.bundleIdentifier,
           FocusObserver.display(
               for: frontmost,
               display1Frame: bounds.display1,
               display2Frame: bounds.display2
           ) == display {
            candidates.append(bundleId)
        }

        var seen = Set<String>()
        for bundleId in candidates where seen.insert(bundleId).inserted {
            if let result = activateBundleId(bundleId, display: display, history: history) {
                return result
            }
        }
        return .noAppFound
    }

    private static func activateBundleId(
        _ bundleId: String,
        display: DisplayNumber,
        history: FocusHistory
    ) -> FocusActivationResult? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
            return nil
        }
        guard app.activate(options: [.activateIgnoringOtherApps]) else { return nil }
        history.recordFocusChange(app: AppRef(bundleIdentifier: bundleId), display: display)
        return .activated(appName: app.localizedName)
    }

}

// MARK: - FocusObserver

@MainActor
final class FocusObserver {
    private let history: FocusHistory
    private var observer: NSObjectProtocol?
    var onFocusRecorded: ((DisplayNumber, String, String) -> Void)?

    init(history: FocusHistory) {
        self.history = history
    }

    func start() {
        stop()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                    return
                }
                self?.recordFocus(for: app)
            }
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }

    private func recordFocus(for app: NSRunningApplication) {
        guard let bundleId = app.bundleIdentifier else { return }
        guard let bounds = DisplayMonitor.dualDisplayBounds() else { return }
        guard let display = Self.display(
            for: app,
            display1Frame: bounds.display1,
            display2Frame: bounds.display2
        ) else {
            return
        }
        history.recordFocusChange(app: AppRef(bundleIdentifier: bundleId), display: display)
        let name = app.localizedName ?? bundleId
        onFocusRecorded?(display, name, bundleId)
        Log.info("system D\(display.rawValue) → \(name)")
    }

    static func display(
        for app: NSRunningApplication,
        display1Frame: CGRect,
        display2Frame: CGRect
    ) -> DisplayNumber? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let pid = app.processIdentifier
        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid else {
                continue
            }
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = windowBounds(from: boundsDict)
            else {
                continue
            }
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            return FocusDisplayMapping.display(
                for: center,
                display1Frame: display1Frame,
                display2Frame: display2Frame
            )
        }
        return nil
    }
}

// MARK: - Window helpers

private func onScreenWindows() -> [[String: Any]]? {
    CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
}

private func frontmostBundleId(
    on display: DisplayNumber,
    display1Frame: CGRect,
    display2Frame: CGRect
) -> String? {
    guard let windowList = onScreenWindows() else { return nil }
    var best: (area: CGFloat, bundleId: String)?
    for info in windowList {
        guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
        guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let bounds = windowBounds(from: boundsDict)
        else { continue }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        guard FocusDisplayMapping.display(
            for: center,
            display1Frame: display1Frame,
            display2Frame: display2Frame
        ) == display else { continue }
        guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
              let app = NSRunningApplication(processIdentifier: ownerPID),
              app.activationPolicy == .regular,
              let bundleId = app.bundleIdentifier
        else { continue }
        let area = bounds.width * bounds.height
        if best == nil || area > best!.area {
            best = (area, bundleId)
        }
    }
    return best?.bundleId
}

/// Any regular app with a visible window on the target display (last resort).
private func anyRegularBundleId(
    on display: DisplayNumber,
    display1Frame: CGRect,
    display2Frame: CGRect
) -> String? {
    guard let windowList = onScreenWindows() else { return nil }
    var seen = Set<pid_t>()
    for info in windowList {
        guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
        guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let bounds = windowBounds(from: boundsDict)
        else { continue }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        guard FocusDisplayMapping.display(
            for: center,
            display1Frame: display1Frame,
            display2Frame: display2Frame
        ) == display else { continue }
        guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
              seen.insert(ownerPID).inserted,
              let app = NSRunningApplication(processIdentifier: ownerPID),
              app.activationPolicy == .regular,
              let bundleId = app.bundleIdentifier
        else { continue }
        return bundleId
    }
    return nil
}

private func windowBounds(from dict: [String: Any]) -> CGRect? {
    guard let x = dict["X"] as? CGFloat,
          let y = dict["Y"] as? CGFloat,
          let width = dict["Width"] as? CGFloat,
          let height = dict["Height"] as? CGFloat
    else {
        return nil
    }
    return CGRect(x: x, y: y, width: width, height: height)
}
