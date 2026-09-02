import AppKit

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isFloatingPanel = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        minSize = NSSize(width: 320, height: 400)
        collectionBehavior = [.moveToActiveSpace]
        level = .statusBar
        backgroundColor = .clear
    }
}