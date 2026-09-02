import Foundation

final class AppState: ObservableObject {
    let settingsStore: SettingsStore
    let taskStore: TaskStore
    let panelBridge: PanelBridge

    init(settingsStore: SettingsStore, taskStore: TaskStore, panelBridge: PanelBridge) {
        self.settingsStore = settingsStore
        self.taskStore = taskStore
        self.panelBridge = panelBridge
    }
}