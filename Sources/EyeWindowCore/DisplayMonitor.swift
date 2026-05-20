import CoreGraphics
import Foundation

/// Detected display configuration for dual-display gating.
public enum DisplayLayout: Equatable, Sendable {
    case dual(DualLayout)
    case notDual
}

/// Reads connected displays and classifies dual vs non-dual layout.
public enum DisplayMonitor {
    /// Pure helper for tests: classify from screen count and global minX of display 1 vs 2.
    public static func layoutFromDisplayCount(
        _ count: Int,
        display1MinX: CGFloat,
        display2MinX: CGFloat
    ) -> DisplayLayout {
        guard count == 2 else { return .notDual }
        return .dual(DualLayout(display1IsLeft: display1MinX <= display2MinX))
    }

    /// Returns dual layout when exactly two displays are active; otherwise `notDual`.
    public static func currentDisplays() -> DisplayLayout {
        guard let bounds = dualDisplayBounds() else { return .notDual }
        return layoutFromDisplayCount(
            2,
            display1MinX: bounds.display1.minX,
            display2MinX: bounds.display2.minX
        )
    }

    /// Bounds for display 1 and 2 when exactly two displays are active.
    public static func dualDisplayBounds() -> (display1: CGRect, display2: CGRect)? {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count == 2 else { return nil }

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displayIDs, &count)

        return (CGDisplayBounds(displayIDs[0]), CGDisplayBounds(displayIDs[1]))
    }
}
