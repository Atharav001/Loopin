import Foundation
import Combine

/// Single source of truth for timer phase and countdown state.
/// Views and the status bar only observe `session`; they never own countdown state.
final class TimerEngine: ObservableObject {
    let session: TimerSession

    private var ticker: Timer?
    private var currentDuration: TimeInterval = 0

    init(session: TimerSession) {
        self.session = session
    }

    /// Total seconds for the current phase under the active preset.
    private var durationForCurrentPhase: TimeInterval {
        guard let preset = session.activePreset else { return 0 }
        switch session.phase {
        case .focus:
            return TimeInterval(preset.focusMinutes) * 60
        case .breakShort:
            return TimeInterval(preset.breakMinutes) * 60
        case .breakLong:
            return TimeInterval(preset.longBreakMinutes) * 60
        case .idle:
            return 0
        }
    }

    // MARK: - Actions

    func startFocus() {
        guard let preset = session.activePreset else { return }
        session.phase = .focus
        session.linkedTaskId = nil
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

    /// Completes the running phase and advances to the next.
    /// Called on timer expiry and when the user taps the "done/skip" action.
    func completePhase() {
        switch session.phase {
        case .focus:
            session.completedFocusCyclesToday += 1
            startBreak()
        case .breakShort, .breakLong, .idle:
            reset()
        }
    }

    func pause() {
        guard session.phase != .idle, !session.isPaused else { return }
        session.isPaused = true
        ticker?.invalidate()
        ticker = nil
    }

    func resume() {
        guard session.phase != .idle, session.isPaused else { return }
        session.isPaused = false
        startTicker()
    }

    func skip() {
        guard session.phase != .idle else { return }
        completePhase()
    }

    func reset() {
        ticker?.invalidate()
        ticker = nil
        session.phase = .idle
        session.isPaused = false
        session.remainingSeconds = 0
        session.linkedTaskId = nil
    }

    /// Recomputes the current phase's total duration from the (possibly edited)
    /// active preset. Preserves elapsed progress proportionally.
    func synchronizeWithPreset() {
        guard session.phase != .idle else { return }
        let newDuration = durationForCurrentPhase
        guard newDuration > 0 else { return }
        currentDuration = newDuration
        if session.remainingSeconds > newDuration {
            session.remainingSeconds = newDuration
        }
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

    /// Total session elapsed seconds for progress ring: phase total minus remaining.
    var elapsedForRing: TimeInterval {
        max(0, currentDuration - session.remainingSeconds)
    }

    private func tick() {
        guard session.phase != .idle, !session.isPaused else { return }
        session.remainingSeconds -= 1

        if session.remainingSeconds <= 0 {
            session.remainingSeconds = 0
            completePhase()
        }
    }
}