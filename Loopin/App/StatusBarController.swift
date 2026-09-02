import AppKit
import Combine

enum MenuBarIconState {
    case idle
    case focusRunning
    case breakRunning
}

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let panelController: PanelController
    private let timerSession: TimerSession

    private let pulseAnimationKey = "reminderPulse"
    private var iconState: MenuBarIconState = .idle

    init(panelController: PanelController, timerSession: TimerSession) {
        self.panelController = panelController
        self.timerSession = timerSession
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        guard let button = statusItem.button else { return }
        button.wantsLayer = true
        button.image = iconImage(for: iconState)
        button.image?.isTemplate = true
        button.target = self
        button.action = #selector(togglePanel)
    }

    func refreshIcon() {
        let pending = timerSession.reminderPending
        switch timerSession.phase {
        case .focus:
            iconState = .focusRunning
        case .breakShort, .breakLong:
            iconState = .breakRunning
        case .idle:
            iconState = .idle
        }

        guard let button = statusItem.button else { return }

        if pending {
            // Stage 1: cycle's symbol tinted accent + gentle pulse (anti-habituation).
            button.image?.isTemplate = false
            button.contentTintColor = NSColor(hex: accentHex)
            startPulse(on: button)
        } else {
            button.image?.isTemplate = true
            button.contentTintColor = nil
            stopPulse(on: button)
        }
    }

    private var accentHex: String {
        switch iconState {
        case .idle: return "#9B7BFF"
        case .focusRunning: return "#3DDC97"
        case .breakRunning: return "#FF7A6B"
        }
    }

    private func startPulse(on button: NSStatusBarButton) {
        if button.layer?.animation(forKey: pulseAnimationKey) != nil { return }

        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.08
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        button.layer?.add(pulse, forKey: pulseAnimationKey)
    }

    private func stopPulse(on button: NSStatusBarButton) {
        button.layer?.removeAnimation(forKey: pulseAnimationKey)
        button.layer?.transform = CATransform3DIdentity
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

private extension NSColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}