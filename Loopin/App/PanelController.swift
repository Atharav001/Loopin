import AppKit
import SwiftUI
import Combine

final class PanelController {
    private let panel: FloatingPanel
    private let settingsStore: SettingsStore

    let bridge: PanelBridge

    var isVisible: Bool { panel.isVisible }

    init(settingsStore: SettingsStore, panelBridge: PanelBridge) {
        self.settingsStore = settingsStore
        self.bridge = panelBridge
        self.bridge.isPinned = settingsStore.settings.pinnedByDefault

        let panel = FloatingPanel()
        self.panel = panel

        if let frame = settingsStore.settings.panelFrame {
            panel.setFrame(frame, display: false)
        }

        if bridge.isPinned {
            applyPinned()
        }

        bridge.onTogglePin = { [weak self] in
            self?.togglePinned()
        }

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

    func installRoot(appState: AppState) {
        let contentController = NSHostingController(
            rootView: PanelRootView()
                .environmentObject(appState.settingsStore)
                .environmentObject(appState.taskStore)
                .environmentObject(appState.panelBridge)
                .environmentObject(appState.timerEngine)
                .environmentObject(appState.timerSession)
        )
        panel.contentViewController = contentController
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