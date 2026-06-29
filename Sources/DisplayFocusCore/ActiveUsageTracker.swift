import Foundation

public struct ActiveUsageConfiguration: Equatable, Sendable {
    public static let `default` = ActiveUsageConfiguration(
        idleThreshold: 5 * 60,
        breakInterval: 60 * 60
    )

    public var idleThreshold: TimeInterval
    public var breakInterval: TimeInterval

    public init(idleThreshold: TimeInterval, breakInterval: TimeInterval) {
        self.idleThreshold = idleThreshold
        self.breakInterval = breakInterval
    }
}

public struct ActiveUsageState: Equatable, Sendable {
    public var accumulatedSeconds: TimeInterval
    public var lastActivityAt: Date?
    public var lastTickAt: Date?
    public var remindersPaused: Bool

    public init(
        accumulatedSeconds: TimeInterval = 0,
        lastActivityAt: Date? = nil,
        lastTickAt: Date? = nil,
        remindersPaused: Bool = false
    ) {
        self.accumulatedSeconds = accumulatedSeconds
        self.lastActivityAt = lastActivityAt
        self.lastTickAt = lastTickAt
        self.remindersPaused = remindersPaused
    }

    public func secondsUntilBreak(config: ActiveUsageConfiguration = .default) -> TimeInterval {
        max(0, config.breakInterval - accumulatedSeconds)
    }

    public func isIdle(at now: Date, config: ActiveUsageConfiguration = .default) -> Bool {
        guard let lastActivityAt else { return true }
        return now.timeIntervalSince(lastActivityAt) > config.idleThreshold
    }
}

public enum ActiveUsageEffect: Equatable, Sendable {
    case none
    case triggerBreak
}

public enum BlinkTrackingMode: String, CaseIterable, Sendable {
    case clock
    case activity

    public var menuLabel: String {
        switch self {
        case .clock: return "Clock (always counts)"
        case .activity: return "Keyboard & mouse (active time)"
        }
    }
}

public struct ActiveUsageTracker: Sendable {
    public let config: ActiveUsageConfiguration

    public init(config: ActiveUsageConfiguration = .default) {
        self.config = config
    }

    public func recordActivity(_ state: ActiveUsageState, at date: Date) -> ActiveUsageState {
        var next = state
        next.lastActivityAt = date
        if next.lastTickAt == nil {
            next.lastTickAt = date
        }
        return next
    }

    public func setPaused(_ state: ActiveUsageState, paused: Bool) -> ActiveUsageState {
        var next = state
        next.remindersPaused = paused
        return next
    }

    public func completeBreak(_ state: ActiveUsageState, at date: Date) -> ActiveUsageState {
        ActiveUsageState(accumulatedSeconds: 0, lastActivityAt: state.lastActivityAt, lastTickAt: date, remindersPaused: state.remindersPaused)
    }

    public func tick(
        _ state: ActiveUsageState,
        at now: Date,
        overlayActive: Bool,
        mode: BlinkTrackingMode = .clock
    ) -> (ActiveUsageState, ActiveUsageEffect) {
        var next = state

        guard !next.remindersPaused, !overlayActive else {
            next.lastTickAt = now
            return (next, .none)
        }

        switch mode {
        case .clock:
            accumulateElapsed(&next, at: now)
        case .activity:
            if let lastActivityAt = next.lastActivityAt,
               now.timeIntervalSince(lastActivityAt) <= config.idleThreshold {
                accumulateElapsed(&next, at: now)
            } else {
                next.lastTickAt = now
            }
        }

        if next.accumulatedSeconds >= config.breakInterval {
            return (next, .triggerBreak)
        }
        return (next, .none)
    }

    private func accumulateElapsed(_ state: inout ActiveUsageState, at now: Date) {
        let previousTick = state.lastTickAt ?? now
        let delta = max(0, now.timeIntervalSince(previousTick))
        state.accumulatedSeconds += delta
        state.lastTickAt = now
    }
}
