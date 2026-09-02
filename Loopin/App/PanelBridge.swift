import Foundation
import Combine

/// Lightweight bridge between AppKit (PanelController) and SwiftUI views.
/// Keeps SwiftUI independent from direct NSWindow manipulation while still
/// reflecting pin state for the pinned-glow indicator.
final class PanelBridge: ObservableObject {
    @Published var isPinned: Bool = false

    var onTogglePin: (() -> Void)?

    func togglePin() {
        onTogglePin?()
    }
}