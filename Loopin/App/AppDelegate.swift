import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var panelController: PanelController?
    private var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settingsStore = SettingsStore()
        let taskStore = TaskStore()
        let timerSession = TimerSession()
        let panelBridge = PanelBridge()

        let panelController = PanelController(
            settingsStore: settingsStore,
            panelBridge: panelBridge
        )
        let appState = AppState(
            settingsStore: settingsStore,
            taskStore: taskStore,
            panelBridge: panelBridge,
            timerSession: timerSession
        )
        self.appState = appState

        panelController.installRoot(appState: appState)
        self.panelController = panelController

        let statusBarController = StatusBarController(
            panelController: panelController,
            timerSession: timerSession
        )
        self.statusBarController = statusBarController

        timerSession.$phase
            .sink { _ in statusBarController.refreshIcon() }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.saveFrame()
        appState?.taskStore.saveNow()
        appState?.settingsStore.saveNow()
    }
}