import CoreGraphics
import Foundation

/// Pure mapping from desktop coordinates to numbered displays (same frames as DisplayMonitor).
public enum FocusDisplayMapping {
    public static func display(
        for point: CGPoint,
        display1Frame: CGRect,
        display2Frame: CGRect
    ) -> DisplayNumber {
        let in1 = display1Frame.contains(point)
        let in2 = display2Frame.contains(point)
        switch (in1, in2) {
        case (true, false):
            return .one
        case (false, true):
            return .two
        default:
            return nearestDisplay(to: point, display1Frame: display1Frame, display2Frame: display2Frame)
        }
    }

    private static func nearestDisplay(
        to point: CGPoint,
        display1Frame: CGRect,
        display2Frame: CGRect
    ) -> DisplayNumber {
        let d1 = distanceSquared(point, CGPoint(x: display1Frame.midX, y: display1Frame.midY))
        let d2 = distanceSquared(point, CGPoint(x: display2Frame.midX, y: display2Frame.midY))
        return d1 <= d2 ? .one : .two
    }

    private static func distanceSquared(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }
}
