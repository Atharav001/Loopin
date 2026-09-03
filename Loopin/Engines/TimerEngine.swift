import Foundation
import Combine

/// Single source of truth for timer phase and countdown state across all three
/// modes (Pomodoro / Timer / Stopwatch, V1_IMPROVEMENTS §2).
/// Views and the status bar only observe `session`; they never own countdown state.
final class TimerEngine: ObservableObject {
    let session: TimerSession

    /// Invoked when a focus/break session or a Timer-mode countdown ends
    /// (natural expiry), with the phase that just completed. The reminder
    /// scheduler uses this to arm the two-stage escalation. Never fires for
    /// user-initiated skips/resets or mode switches.
    var onSessionEnded: ((TimerPhase) -> Void)?

    private var ticker: Timer?
    private var currentDuration: TimeInterval = 0

    init(session: TimerSession) {
        self.session = session
    }

    /// True when any mode has a live (non-idle) count — used to decide whether a
    /// mode switch warrants a lightweight continuity prompt (§2.2).
    var isSessionActive: Bool {
        session.phase != .idle || session.mode == .stopwatch
    }

    /// Total seconds for the current phase under the active preset (Pomodoro).
    private var durationForCurrentPhase: TimeInterval {
        guard let preset = session.activePreset else { return 0 }
        switch session.phase {
        case .focus:
            return TimeInterval(preset.focusMinutes) * 60
        case .breakShort:
            return TimeInterval(preset.breakMinutes) * 60
        case .breakLong:
            return TimeInterval(preset.longBreakMinutes) * 60
        case .idle, .timer:
            return 0
        }
    }

    // MARK: - Mode actions

    /// Starts a Pomodoro focus phase. `linkedTaskId` links a task (FR-6.5).
    func startFocus(linkedTaskId: UUID? = nil) {
        guard let preset = session.activePreset else { return }
        session.mode = .pomodoro
        session.phase = .focus
        session.linkedTaskId = linkedTaskId
        session.isPaused = false
        beginPhase(duration: TimeInterval(preset.focusMinutes) * 60)
    }

    /// Starts the break that follows a focus session: short by default,
    /// long after `cyclesBeforeLongBreak` completed focus cycles today.
    func startBreak(manual: Bool = false) {
        guard let preset = session.activePreset else { return }

        let shouldLongBreak = session.completedFocusCyclesToday > 0 &&
            session.completedFocusCyclesToday % preset.cyclesBeforeLongBreak == 0

        if shouldLongBreak {
            session.phase = .breakLong
            beginPhase(duration: TimeInterval(preset.longBreakMinutes) * 60)
        } else {
            session.phase = .breakShort
            beginPhase(duration: TimeInterval(preset.breakMinutes) * 60)
        }
        _ = manual
    }

    /// Timer mode (§2.1): a single countdown of `duration` seconds to zero.
    /// No automatic cycle repeat, no break phase. Uses the ring visual with a
    /// neutral accent.
    func startTimer(duration: TimeInterval) {
        session.mode = .timer
        session.phase = .timer
        session.linkedTaskId = nil
        session.isPaused = false
        session.timerTotalSeconds = duration
        currentDuration = duration
        session.remainingSeconds = duration
        startTicker()
    }

    /// Stopwatch mode (§2.1): counts up from zero. No ring (there's nothing to
    /// measure progress against) — rendered as a plain digital readout.
    func startStopwatch() {
        session.mode = .stopwatch
        session.phase = .idle
        session.isPaused = false
        session.elapsedSeconds = 0
        session.remainingSeconds = 0
        startTicker()
    }

    /// Completes a Timer-mode countdown: pauses, fires the ended callback, then
    /// drops back to the mode's idle baseline (does NOT auto-repeat).
    private func completeTimerCountdown() {
        session.remainingSeconds = 0
        ticker?.invalidate()
        ticker = nil
        session.phase = .timer
        onSessionEnded?(.timer)
        session.isPaused = true
        session.phase = .idle
        session.mode = .timer
    }

    /// Stops whatever the current mode is doing (used by a mode switch) without
    /// firing a reminder. §2.3: switching from idle is instant.
    func stopCurrent() {
        ticker?.invalidate()
        ticker = nil
        session.phase = .idle
        session.isPaused = false
        session.remainingSeconds = 0
        session.elapsedSeconds = 0
        session.timerTotalSeconds = 0
        session.linkedTaskId = nil
        session.reminderPending = false
    }

    /// Prepares the engine for a switch to a different mode, clearing any live
    /// count. The UI decides whether to confirm first (§2.2).
    func switchMode(to newMode: TimerMode) {
        stopCurrent()
        session.mode = newMode
    }

    // MARK: - Pomodoro actions

    /// Completes the running phase and advances to the next (Pomodoro).
    func completePhase() {
        let endingPhase = session.phase
        switch session.phase {
        case .focus:
            session.completedFocusCyclesToday += 1
            onSessionEnded?(.focus)
            startBreak()
        case .breakShort, .breakLong:
            onSessionEnded?(endingPhase)
            reset()
        case .idle, .timer:
            reset()
        }
    }

    /// User-initiated skip: advances to the next phase without arming a reminder
    /// (the user is present, so no escalation is needed).
    func skip() {
        guard session.phase != .idle else { return }
        switch session.phase {
        case .focus:
            session.completedFocusCyclesToday += 1
            startBreak()
        case .breakShort, .breakLong:
            reset()
        case .idle, .timer:
            reset()
        }
    }

    // MARK: - Transport controls

    func pause() {
        guard !session.isPaused else { return }
        guard session.mode == .stopwatch ? true : session.phase != .idle else { return }
        session.isPaused = true
        ticker?.invalidate()
        ticker = nil
    }

    func resume() {
        guard session.isPaused else { return }
        session.isPaused = false
        startTicker()
    }

    func reset() {
        ticker?.invalidate()
        ticker = nil
        session.phase = .idle
        session.isPaused = false
        session.remainingSeconds = 0
        session.elapsedSeconds = 0
        session.timerTotalSeconds = 0
        session.linkedTaskId = nil
        session.reminderPending = false
    }

    /// Recomputes the current Pomodoro phase's total duration from the (possibly
    /// edited) active preset. A mid-session preset change must not retroactively
    /// truncate the running cycle (FR-6.4) — it takes effect on the next cycle
    /// boundary. So this only ever EXTENDS a running phase; it never cuts it short.
    func synchronizeWithPreset() {
        guard session.mode == .pomodoro, session.phase != .idle else { return }
        let newDuration = durationForCurrentPhase
        guard newDuration > currentDuration else { return }
        let added = newDuration - currentDuration
        currentDuration = newDuration
        session.remainingSeconds += added
    }

    // MARK: - Internals

    private func beginPhase(duration: TimeInterval) {
        currentDuration = duration
        session.remainingSeconds = duration
        startTicker()
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    /// Total session elapsed seconds for the progress ring (Pomodoro/Timer).
    var elapsedForRing: TimeInterval {
        switch session.mode {
        case .pomodoro, .timer:
            return max(0, currentDuration - session.remainingSeconds)
        case .stopwatch:
            return session.elapsedSeconds
        }
    }

    private func tick() {
        guard !session.isPaused else { return }

        switch session.mode {
        case .pomodoro:
            guard session.phase != .idle else { return }
            session.remainingSeconds -= 1
            if session.remainingSeconds <= 0 {
                session.remainingSeconds = 0
                completePhase()
            }
        case .timer:
            guard session.phase == .timer else { return }
            session.remainingSeconds -= 1
            if session.remainingSeconds <= 0 {
                completeTimerCountdown()
            }
        case .stopwatch:
            session.elapsedSeconds += 1
        }
    }
}