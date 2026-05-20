import CoreGraphics
import Foundation

/// Where on a display the calibration red dot appears (three targets per screen).
public enum CalibrationTarget: Int, CaseIterable, Sendable, Codable {
    case center
    case left
    case right

    public var label: String {
        switch self {
        case .center: return "center"
        case .left: return "left"
        case .right: return "right"
        }
    }

    /// Horizontal position as fraction of screen width from `minX`.
    public var horizontalFraction: CGFloat {
        switch self {
        case .center: return 0.5
        case .left: return 0.25
        case .right: return 0.75
        }
    }

    /// Red-dot center in global screen coordinates (AppKit / CG).
    public func dotCenter(inScreenFrame frame: CGRect) -> CGPoint {
        CGPoint(
            x: frame.minX + frame.width * horizontalFraction,
            y: frame.midY
        )
    }
}
