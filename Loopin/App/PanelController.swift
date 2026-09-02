import AppKit
import SwiftUI
import Combine

final class PanelController {
    private let panel: FloatingPanel
    private let settingsStore: SettingsStore
    private let bridge = PanelBridge()
    private var cancellables = Set<AnyCancellable>()

    var isVisible: Bool { panel.isVisible }

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore

        let panel = FloatingPanel()
        self.panel = panel
        self.bridge.isPinned = settingsStore.settings.pinnedByDefault

        if let frame = settingsStore.settings.panelFrame {
            panel.setFrame(frame, display: false)
        }

        if bridge.isPinned {
            applyPinned()
        }

        bridge.onTogglePin = { [weak self] in
            self?.togglePinned()
        }

        let contentController = NSHostingController(
            rootView: PanelRootView()
                .environmentObject(bridge)
        )
        panel.contentViewController = contentController

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMoveOrResize),
            name: NSWindow.didMoveNotification,
            object: panel
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMoveOrResize),
            name: NSWindow.didResizeNotification,
            object: panel
        )
    }

    func show() {
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func setPinned(_ pinned: Bool) {
        bridge.isPinned = pinned
        settingsStore.settings.pinnedByDefault = pinned
        settingsStore.saveNow()
        if pinned {
            applyPinned()
        } else {
            applyUnpinned()
        }
    }

    func togglePinned() {
        setPinned(!bridge.isPinned)
    }

    func saveFrame() {
        settingsStore.settings.panelFrame = panel.frame
        settingsStore.saveNow()
    }

    private func applyPinned() {
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    private func applyUnpinned() {
        panel.level = .normal
        panel.collectionBehavior = [.moveToActiveSpace]
    }

    @objc private func windowDidMoveOrResize(_ notification: Notification) {
        saveFrame()
    }
}