import AppKit
import SwiftUI

final class PanelController {
    private let panel: FloatingPanel

    init() {
        panel = FloatingPanel()
        let contentController = NSHostingController(rootView: PanelRootView())
        panel.contentViewController = contentController
    }

    var isVisible: Bool { panel.isVisible }

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
}