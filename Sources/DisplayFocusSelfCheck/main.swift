import CoreGraphics
import Foundation
import DisplayFocusCore

precondition(!DisplayFocusCore.version.isEmpty)

let history = FocusHistory()
let app = AppRef(bundleIdentifier: "com.example.app")
history.recordFocusChange(app: app, display: .one)
precondition(history.lastFocused(display: .one) == app)

let d1 = CGRect(x: 0, y: 0, width: 1920, height: 1080)
let d2 = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
precondition(
    FocusDisplayMapping.display(for: CGPoint(x: 960, y: 540), display1Frame: d1, display2Frame: d2) == .one
)
precondition(
    FocusDisplayMapping.display(for: CGPoint(x: 2880, y: 540), display1Frame: d1, display2Frame: d2) == .two
)

guard case .dual(let dual) = DisplayMonitor.layoutFromDisplayCount(2, display1MinX: 0, display2MinX: 1920) else {
    preconditionFailure("expected dual")
}
precondition(dual.display1IsLeft)
precondition(DisplayMonitor.layoutFromDisplayCount(3, display1MinX: 0, display2MinX: 1920) == .notDual)

print("DisplayFocusSelfCheck OK")
