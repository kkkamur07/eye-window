import CoreGraphics
import Foundation
import DisplayFocusCore

precondition(!DisplayFocusCore.version.isEmpty)

let history = FocusHistory()
let app = AppRef(bundleIdentifier: "com.example.app")
history.recordFocusChange(app: app, display: .one)
precondition(history.lastFocused(display: .one) == app)
precondition(history.stack(for: .one) == [app])

let appA = AppRef(bundleIdentifier: "com.example.a")
let appB = AppRef(bundleIdentifier: "com.example.b")
let appC = AppRef(bundleIdentifier: "com.example.c")
history.recordFocusChange(app: appA, display: .two)
history.recordFocusChange(app: appB, display: .two)
history.recordFocusChange(app: appC, display: .two)
precondition(history.stack(for: .two) == [appC, appB, appA])

history.recordFocusChange(app: appB, display: .two)
precondition(history.stack(for: .two) == [appB, appC, appA])

history.remove(app: appB)
precondition(history.stack(for: .two) == [appC, appA])

precondition(history.nextForRotate(display: .two, currentApp: appC) == .next(appA))
precondition(history.nextForRotate(display: .two, currentApp: appA) == .next(appC))
precondition(history.nextForRotate(display: .two, currentApp: appB) == .noOp)

let soloHistory = FocusHistory()
let soloApp = AppRef(bundleIdentifier: "com.example.solo")
soloHistory.recordFocusChange(app: soloApp, display: .one)
precondition(soloHistory.nextForRotate(display: .one, currentApp: soloApp) == .noOp)

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

let defaultConfig = ActiveUsageConfiguration.default
precondition(defaultConfig.idleThreshold == 300)
precondition(defaultConfig.breakInterval == 3600)

let testConfig = ActiveUsageConfiguration(idleThreshold: 3, breakInterval: 10)
let usageTracker = ActiveUsageTracker(config: testConfig)
let usageOrigin = Date(timeIntervalSinceReferenceDate: 100_000)

var usageState = ActiveUsageState(lastTickAt: usageOrigin)
usageState = usageTracker.recordActivity(usageState, at: usageOrigin)
precondition(usageState.lastActivityAt == usageOrigin)
precondition(usageState.lastTickAt == usageOrigin)

var usageEffect: ActiveUsageEffect
var usageTick = usageOrigin
(usageState, usageEffect) = usageTracker.tick(usageState, at: usageOrigin.addingTimeInterval(1), overlayActive: false)
precondition(usageEffect == .none)
precondition(usageState.accumulatedSeconds == 1)
(usageState, usageEffect) = usageTracker.tick(usageState, at: usageOrigin.addingTimeInterval(2), overlayActive: false)
precondition(usageEffect == .none)
precondition(usageState.accumulatedSeconds == 2)

(usageState, usageEffect) = usageTracker.tick(usageState, at: usageOrigin.addingTimeInterval(5), overlayActive: false, mode: .activity)
precondition(usageEffect == .none)
precondition(usageState.accumulatedSeconds == 2)

usageState = ActiveUsageState(lastTickAt: usageOrigin)
usageState = usageTracker.recordActivity(usageState, at: usageOrigin)
(usageState, usageEffect) = usageTracker.tick(usageState, at: usageOrigin.addingTimeInterval(2), overlayActive: false, mode: .clock)
precondition(usageState.accumulatedSeconds == 2)
usageState = usageTracker.setPaused(usageState, paused: true)
(usageState, usageEffect) = usageTracker.tick(usageState, at: usageOrigin.addingTimeInterval(5), overlayActive: false)
precondition(usageEffect == .none)
precondition(usageState.accumulatedSeconds == 2)

usageState = ActiveUsageState(lastTickAt: usageOrigin)
usageState = usageTracker.recordActivity(usageState, at: usageOrigin)
(usageState, usageEffect) = usageTracker.tick(usageState, at: usageOrigin.addingTimeInterval(2), overlayActive: true)
precondition(usageState.accumulatedSeconds == 0)
(usageState, usageEffect) = usageTracker.tick(usageState, at: usageOrigin.addingTimeInterval(3), overlayActive: false)
precondition(usageState.accumulatedSeconds == 1)

usageState = ActiveUsageState(lastTickAt: usageOrigin)
usageTick = usageOrigin
usageState = usageTracker.recordActivity(usageState, at: usageTick)
for second in 1...6 {
    usageTick = usageOrigin.addingTimeInterval(TimeInterval(second))
    usageState = usageTracker.recordActivity(usageState, at: usageTick)
    (usageState, usageEffect) = usageTracker.tick(usageState, at: usageTick, overlayActive: false)
    precondition(usageEffect == .none)
}
precondition(usageState.accumulatedSeconds == 6)
usageState = usageTracker.completeBreak(usageState, at: usageTick)
precondition(usageState.accumulatedSeconds == 0)

usageState = ActiveUsageState(lastTickAt: usageOrigin)
usageTick = usageOrigin
usageState = usageTracker.recordActivity(usageState, at: usageTick)
for second in 1...9 {
    usageTick = usageOrigin.addingTimeInterval(TimeInterval(second))
    usageState = usageTracker.recordActivity(usageState, at: usageTick)
    (usageState, usageEffect) = usageTracker.tick(usageState, at: usageTick, overlayActive: false)
    precondition(usageEffect == .none)
}
usageState = usageTracker.setPaused(usageState, paused: true)
usageTick = usageOrigin.addingTimeInterval(10)
(usageState, usageEffect) = usageTracker.tick(usageState, at: usageTick, overlayActive: false)
precondition(usageEffect == .none)
precondition(usageState.accumulatedSeconds == 9)

usageState = ActiveUsageState(lastTickAt: usageOrigin)
usageTick = usageOrigin
usageState = usageTracker.recordActivity(usageState, at: usageTick)
for second in 1...10 {
    usageTick = usageOrigin.addingTimeInterval(TimeInterval(second))
    usageState = usageTracker.recordActivity(usageState, at: usageTick)
    (usageState, usageEffect) = usageTracker.tick(usageState, at: usageTick, overlayActive: false)
}
precondition(usageEffect == .triggerBreak)
precondition(usageState.accumulatedSeconds == 10)

print("DisplayFocusSelfCheck OK")
