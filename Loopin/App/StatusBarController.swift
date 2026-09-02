import AppKit
import Combine

enum MenuBarIconState {
    case idle
    case focusRunning
    case breakRunning
}

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let panelController: PanelController
    private let timerSession: TimerSession

    private var iconState: MenuBarIconState = .idle

    init(panelController: PanelController, timerSession: TimerSession) {
        self.panelController = panelController
        self.timerSession = timerSession
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        button.image = iconImage(for: iconState)
        button.image?.isTemplate = true
        button.target = self
        button.action = #selector(togglePanel)
    }

    func refreshIcon() {
        switch timerSession.phase {
        case .focus:
            iconState = .focusRunning
        case .breakShort, .breakLong:
            iconState = .breakRunning
        case .idle:
            iconState = .idle
        }

        if let button = statusItem.button {
            button.image = iconImage(for: iconState)
            button.image?.isTemplate = true
        }
    }

    private func iconImage(for state: MenuBarIconState) -> NSImage? {
        let symbol: String
        switch state {
        case .idle:
            symbol = "checklist"
        case .focusRunning:
            symbol = "timer"
        case .breakRunning:
            symbol = "cup.and.saucer.fill"
        }
        return NSImage(systemSymbolName: symbol, accessibilityDescription: "Loopin")
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }
}