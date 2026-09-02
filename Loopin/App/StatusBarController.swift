import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let panelController: PanelController

    init(panelController: PanelController) {
        self.panelController = panelController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "checklist",
                               accessibilityDescription: "Loopin")
        button.image?.isTemplate = true
        button.target = self
        button.action = #selector(togglePanel)
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }
}