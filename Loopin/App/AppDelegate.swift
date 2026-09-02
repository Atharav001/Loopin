import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var panelController: PanelController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settingsStore = SettingsStore()
        let timerSession = TimerSession()

        let panelController = PanelController(settingsStore: settingsStore)
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
    }
}