import DisplayFocusCore
import Foundation

@MainActor
final class BlinkReminderCoordinator {
    private var tracker: ActiveUsageTracker
    private var state = ActiveUsageState()
    private var breakPending = false
    private var timer: Timer?
    private var trackingMode: BlinkTrackingMode
    private weak var session: SessionCoordinator?

    init(session: SessionCoordinator) {
        self.session = session
        let breakInterval = BlinkReminderSettings.loadBreakInterval()
        self.trackingMode = BlinkReminderSettings.loadTrackingMode()
        self.tracker = ActiveUsageTracker(
            config: ActiveUsageConfiguration(
                idleThreshold: ActiveUsageConfiguration.default.idleThreshold,
                breakInterval: breakInterval
            )
        )
    }

    func start() {
        state = ActiveUsageState(lastTickAt: Date(), remindersPaused: false)
        breakPending = false
        session?.setBlinkTrackingMode(trackingMode)
        publishState(breakTriggered: false)
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func recordActivity() {
        state = tracker.recordActivity(state, at: Date())
        publishState(breakTriggered: breakPending)
    }

    func setPaused(_ paused: Bool) {
        guard state.remindersPaused != paused else { return }
        state = tracker.setPaused(state, paused: paused)
        publishState(breakTriggered: breakPending)
        Log.info(paused ? "blink reminders: paused" : "blink reminders: resumed")
    }

    func setBreakInterval(_ interval: TimeInterval) {
        guard interval > 0, tracker.config.breakInterval != interval else { return }
        guard !breakPending else { return }

        tracker = ActiveUsageTracker(
            config: ActiveUsageConfiguration(
                idleThreshold: tracker.config.idleThreshold,
                breakInterval: interval
            )
        )
        let paused = state.remindersPaused
        state = ActiveUsageState(lastTickAt: Date(), remindersPaused: paused)
        BlinkReminderSettings.saveBreakInterval(interval)
        publishState(breakTriggered: false)
        Log.info("blink break interval: \(BlinkReminderSettings.intervalLabel(interval))")
    }

    func setTrackingMode(_ mode: BlinkTrackingMode) {
        guard trackingMode != mode else { return }
        guard !breakPending else { return }

        trackingMode = mode
        BlinkReminderSettings.saveTrackingMode(mode)
        let paused = state.remindersPaused
        state = ActiveUsageState(lastTickAt: Date(), remindersPaused: paused)
        session?.setBlinkTrackingMode(mode)
        publishState(breakTriggered: false)
        Log.info("blink tracking mode: \(mode.rawValue)")
    }

    var currentTrackingMode: BlinkTrackingMode {
        trackingMode
    }

    /// Called after a **Blink time overlay** ends (issue 018).
    func completeBreak() {
        breakPending = false
        state = tracker.completeBreak(state, at: Date())
        publishState(breakTriggered: false)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let now = Date()
        let (nextState, effect) = tracker.tick(state, at: now, overlayActive: breakPending, mode: trackingMode)
        state = nextState

        if effect == .triggerBreak {
            breakPending = true
            Log.info("blink time: break due")
            publishState(breakTriggered: true)
            return
        }

        publishState(breakTriggered: breakPending)
    }

    private func publishState(breakTriggered: Bool) {
        let now = Date()
        let isIdle = trackingMode == .activity && state.isIdle(at: now, config: tracker.config)
        session?.updateBlinkReminderState(
            accumulatedSeconds: state.accumulatedSeconds,
            secondsUntilBreak: state.secondsUntilBreak(config: tracker.config),
            breakInterval: tracker.config.breakInterval,
            isIdle: isIdle,
            remindersPaused: state.remindersPaused,
            breakTriggered: breakTriggered
        )
    }
}
