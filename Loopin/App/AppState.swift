import Foundation

final class AppState: ObservableObject {
    let settingsStore: SettingsStore
    let taskStore: TaskStore
    let panelBridge: PanelBridge
    let timerEngine: TimerEngine
    let timerSession: TimerSession

    init(
        settingsStore: SettingsStore,
        taskStore: TaskStore,
        panelBridge: PanelBridge,
        timerSession: TimerSession
    ) {
        self.settingsStore = settingsStore
        self.taskStore = taskStore
        self.panelBridge = panelBridge
        self.timerSession = timerSession
        self.timerEngine = TimerEngine(session: timerSession)
        timerSession.activePreset = settingsStore.settings.presets.first
    }
}