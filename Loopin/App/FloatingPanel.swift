import AppKit

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(
        contentRect: NSRect = NSRect(x: 0, y: 0, width: 360, height: 480),
        minSize: NSSize = NSSize(width: 320, height: 400)
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .resizable, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isFloatingPanel = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        self.minSize = minSize
        collectionBehavior = [.moveToActiveSpace, .participatesInCycle, .fullScreenAuxiliary]
        level = .normal
        backgroundColor = .clear
    }
}