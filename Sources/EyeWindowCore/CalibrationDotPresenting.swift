import CoreGraphics
import Foundation

/// AppKit overlay bridge (implemented by the menu bar app target).
@MainActor
public protocol CalibrationDotPresenting: AnyObject {
    func showCalibrationDot(inScreenFrame frame: CGRect, target: CalibrationTarget)
    func hideCalibrationDot()
}

extension DisplayMonitor {
    /// Screen frame for a numbered display in a dual layout (AppKit / CG coordinates).
    public static func screenFrame(for display: DisplayNumber, layout: DualLayout) -> CGRect? {
        guard let bounds = dualDisplayBounds() else { return nil }
        if layout.display1IsLeft {
            return display == .one ? bounds.display1 : bounds.display2
        }
        return display == .one ? bounds.display2 : bounds.display1
    }
}
