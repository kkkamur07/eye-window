import AppKit
import CoreGraphics

/// Red dot for interactive calibration smoke test.
@MainActor
final class CalibrationOverlay {
    private var window: NSWindow?

    func showDot(at center: CGPoint) {
        hide()
        let dotSize: CGFloat = 24
        let origin = CGPoint(x: center.x - dotSize / 2, y: center.y - dotSize / 2)
        let contentRect = CGRect(origin: origin, size: CGSize(width: dotSize, height: dotSize))

        let panel = NSWindow(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = false

        let dotView = NSView(frame: NSRect(x: 0, y: 0, width: dotSize, height: dotSize))
        dotView.wantsLayer = true
        dotView.layer?.backgroundColor = NSColor.systemRed.cgColor
        dotView.layer?.cornerRadius = dotSize / 2
        panel.contentView = dotView
        panel.orderFrontRegardless()
        window = panel
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}
