import AppKit
import ApplicationServices
import CoreGraphics
import EyeWindowCore

enum FocusActivationResult {
    case activated(appName: String?)
    case notDual
    case accessibilityDenied
    case noAppFound
}

enum FocusController {
    private static var hasRequestedAccessibility = false

    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityIfNeeded() {
        guard !hasRequestedAccessibility else { return }
        hasRequestedAccessibility = true
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func activate(
        display: DisplayNumber,
        history: FocusHistory,
        layout: DualLayout
    ) -> FocusActivationResult {
        guard DisplayMonitor.currentDisplays() != .notDual else {
            return .notDual
        }
        _ = layout

        requestAccessibilityIfNeeded()
        guard isAccessibilityGranted() else {
            return .accessibilityDenied
        }

        guard let bounds = DisplayMonitor.dualDisplayBounds() else {
            return .notDual
        }

        let bundleId: String?
        if let lastFocused = history.lastFocused(display: display),
           NSRunningApplication.runningApplications(withBundleIdentifier: lastFocused.bundleIdentifier).first != nil {
            bundleId = lastFocused.bundleIdentifier
        } else {
            bundleId = frontmostBundleId(on: display, display1Frame: bounds.display1, display2Frame: bounds.display2)
        }

        guard let bundleId,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
        else {
            return .noAppFound
        }

        guard app.activate(options: [.activateIgnoringOtherApps]) else {
            return .noAppFound
        }
        return .activated(appName: app.localizedName)
    }
}

// MARK: - FocusObserver

@MainActor
final class FocusObserver {
    private let history: FocusHistory
    private var observer: NSObjectProtocol?
    var onFocusRecorded: ((DisplayNumber, String) -> Void)?

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
        onFocusRecorded?(display, name)
        EyeWindowLog.info("system focus D\(display.rawValue) → \(name)")
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

private func frontmostBundleId(
    on display: DisplayNumber,
    display1Frame: CGRect,
    display2Frame: CGRect
) -> String? {
    guard let windowList = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
    ) as? [[String: Any]] else {
        return nil
    }

    for info in windowList {
        guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
        guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let bounds = windowBounds(from: boundsDict)
        else {
            continue
        }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        guard FocusDisplayMapping.display(
            for: center,
            display1Frame: display1Frame,
            display2Frame: display2Frame
        ) == display else {
            continue
        }
        guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
              let app = NSRunningApplication(processIdentifier: ownerPID),
              app.activationPolicy == .regular,
              let bundleId = app.bundleIdentifier
        else {
            continue
        }
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
