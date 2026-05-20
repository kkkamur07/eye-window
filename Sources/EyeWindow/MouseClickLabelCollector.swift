import AppKit
import CoreGraphics
import EyeWindowCore

/// Global mouse-down monitor → display label from click position (requires Accessibility).
@MainActor
final class MouseClickLabelCollector {
    private var monitor: Any?

    var onClick: ((CGPoint) -> Void)?

    func start() {
        stop()
        FocusController.requestAccessibilityIfNeeded()
        guard FocusController.isAccessibilityGranted() else {
            EyeWindowLog.info("implicit: mouse monitor needs Accessibility (grant when prompted)")
            return
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            let point = NSEvent.mouseLocation
            Task { @MainActor in
                self?.onClick?(point)
            }
        }
        if monitor != nil {
            EyeWindowLog.info("implicit: listening for mouse clicks (labeled gaze rows)")
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
