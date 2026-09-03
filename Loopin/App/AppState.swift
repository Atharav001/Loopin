import Foundation

final class AppState: ObservableObject {
    let settingsStore: SettingsStore
    let taskStore: TaskStore
    let timerEngine: TimerEngine
    let timerSession: TimerSession
    /// Always-on repeating alarm engine (V1_IMPROVEMENTS §3), distinct from the
    /// Pomodoro timer. Reused by the alarms window and the attention system.
    let alarmEngine: FocusIntervalAlarmEngine

    init(
        settingsStore: SettingsStore,
        taskStore: TaskStore,
        timerSession: TimerSession
    ) {
        self.settingsStore = settingsStore
        self.taskStore = taskStore
        self.timerSession = timerSession
        self.timerEngine = TimerEngine(session: timerSession)
        self.alarmEngine = FocusIntervalAlarmEngine(settingsStore: settingsStore)
        timerSession.activePreset = settingsStore.settings.presets.first
    }
}