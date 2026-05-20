import AppKit
import EyeWindowCore

@MainActor
final class CalibrationDotPresenter: CalibrationDotPresenting {
    private let overlay = CalibrationOverlay()

    func showCalibrationDot(inScreenFrame frame: CGRect, target: CalibrationTarget) {
        overlay.showDot(at: target.dotCenter(inScreenFrame: frame))
    }

    func hideCalibrationDot() {
        overlay.hide()
    }
}
