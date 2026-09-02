import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var panelController: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panelController = PanelController()
        self.panelController = panelController
        self.statusBarController = StatusBarController(panelController: panelController)
    }
}