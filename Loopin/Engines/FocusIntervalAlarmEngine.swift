import Foundation
import Combine
import AppKit

/// Focus Interval Alarm engine (V1_IMPROVEMENTS §3): an always-on, repeating
/// "metronome" alarm independent of the Pomodoro/Timer window. Picks ONE fixed
/// interval from {2,3,5,10,15,20,25} minutes and fires a distinct alert every
/// N minutes, indefinitely, until stopped (or the app quits).
///
/// Distinct type from `TimerEngine` per §7: it is not a Pomodoro preset, it is
/// its own always-on-until-stopped feature that runs concurrently with whatever
/// the Pomodoro/Timer window is doing.
final class FocusIntervalAlarmEngine: ObservableObject {
    let settingsStore: SettingsStore

    /// Fired each time an interval elapses while running. Wire to the attention
    /// system (§6). Runs on the main thread.
    var onAlarm: (() -> Void)?

    private var ticker: Timer?
    private var secondCounter: Int = 0

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        // Resume-with-fresh-interval on launch (§3.4): if it was running, start
        // counting a fresh interval now rather than reconstructing elapsed time.
        if settingsStore.settings.focusIntervalAlarm.isRunning {
            start()
        }
    }

    /// Interval currently selected (minutes), from the fixed preset set.
    var intervalMinutes: Int {
        settingsStore.settings.focusIntervalAlarm.intervalMinutes
    }

    /// True while the repeating alarm is armed.
    var isRunning: Bool {
        settingsStore.settings.focusIntervalAlarm.isRunning
    }

    /// Picks one interval from the fixed preset list (§3.1). Trivial toggles are
    /// allowed while stopped; while running, changing the interval applies on the
    /// next cycle boundary (extend-only, mirroring FR-6.4's non-truncation rule).
    func setInterval(minutes: Int) {
        let clamped = Self.fixedPresets.contains(minutes)
            ? minutes
            : Self.fixedPresets[self.safeIndex(for: minutes)]
        let wasRunning = isRunning
        var alarm = settingsStore.settings.focusIntervalAlarm
        alarm.intervalMinutes = clamped
        settingsStore.settings.focusIntervalAlarm = alarm
        if wasRunning {
            restartInterval()
        }
    }

    /// Starts (or restarts) the repeating alarm with a fresh interval (§3.4).
    func start() {
        guard !isRunning else { return }
        var alarm = settingsStore.settings.focusIntervalAlarm
        alarm.isRunning = true
        settingsStore.settings.focusIntervalAlarm = alarm
        restartInterval()
    }

    /// Stops the alarm; future alerts on this interval are silenced immediately
    /// (§3.2 acceptance).
    func stop() {
        ticker?.invalidate()
        ticker = nil
        secondCounter = 0
        guard isRunning else { return }
        var alarm = settingsStore.settings.focusIntervalAlarm
        alarm.isRunning = false
        settingsStore.settings.focusIntervalAlarm = alarm
    }

    /// Restarts the current interval countdown to a full fresh interval.
    func restartInterval() {
        ticker?.invalidate()
        ticker = nil
        secondCounter = 0
        guard isRunning else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        guard isRunning else { return }
        secondCounter += 1
        let intervalSeconds = intervalMinutes * 60
        if secondCounter >= intervalSeconds {
            secondCounter = 0
            onAlarm?()
        }
    }

    /// Round-robin fallback for an out-of-preset value.
    private func safeIndex(for minutes: Int) -> Int {
        Self.fixedPresets.firstIndex(of: minutes) ?? 4
    }

    /// Fixed preset list (§3.1).
    static let fixedPresets: [Int] = [2, 3, 5, 10, 15, 20, 25]
}

/// Location for the alarm's fixed preset set in one authoritative place.
extension FocusIntervalAlarmEngine {
    /// The fixed interval choices exposed to the UI (§3.1).
    static let intervalChoices = fixedPresets
}