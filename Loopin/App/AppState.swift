import Foundation

final class AppState: ObservableObject {
    let settingsStore: SettingsStore
    let taskStore: TaskStore
    let timerEngine: TimerEngine
    let timerSession: TimerSession

    init(
        settingsStore: SettingsStore,
        taskStore: TaskStore,
        timerSession: TimerSession
    ) {
        self.settingsStore = settingsStore
        self.taskStore = taskStore
        self.timerSession = timerSession
        self.timerEngine = TimerEngine(session: timerSession)
        timerSession.activePreset = settingsStore.settings.presets.first
    }
}