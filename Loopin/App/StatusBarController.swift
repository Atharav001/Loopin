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
    private let opacityAnimationKey = "reminderOpacity"
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
            // Stage 1: cycle symbol tinted accent + anti-habituation pulse variant.
            button.image?.isTemplate = false
            let variant = ReminderVariant.next(after: timerSession.completedFocusCyclesToday)
            button.contentTintColor = variant.color
            startPulse(on: button, variant: variant)
        } else {
            button.image?.isTemplate = true
            button.contentTintColor = nil
            stopPulse(on: button)
        }
    }

    /// Deterministic reminder variants (DESIGN §7) to counter habituation.
    enum ReminderVariant {
        case a, b, c

        static func next(after cycles: Int) -> ReminderVariant {
            switch cycles % 3 {
            case 0: return .a
            case 1: return .b
            default: return .c
            }
        }

        var color: NSColor {
            switch self {
            case .a: return NSColor(hex: "#3DDC97")
            case .b: return NSColor(hex: "#FF7A6B")
            case .c: return NSColor(hex: "#9B7BFF")
            }
        }

        var duration: Double {
            switch self {
            case .a: return 1.2
            case .b: return 1.0
            case .c: return 1.5
            }
        }
    }

    private func startPulse(on button: NSStatusBarButton, variant: ReminderVariant) {
        let duration = variant.duration

        // Scale pulse (all variants; C combines with opacity below).
        if button.layer?.animation(forKey: pulseAnimationKey) == nil {
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 1.0
            pulse.toValue = 1.08
            pulse.duration = duration / 2
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            button.layer?.add(pulse, forKey: pulseAnimationKey)
        }

        // Opacity pulse: subtle for A, none for B handled here; B uses opacity below.
        switch variant {
        case .a:
            removeOpacityPulse(on: button)
        case .b:
            // Opacity 0.6 ↔ 1.0.
            if button.layer?.animation(forKey: opacityAnimationKey) == nil {
                let opacity = CABasicAnimation(keyPath: "opacity")
                opacity.fromValue = 0.6
                opacity.toValue = 1.0
                opacity.duration = duration / 2
                opacity.autoreverses = true
                opacity.repeatCount = .infinity
                button.layer?.add(opacity, forKey: opacityAnimationKey)
            }
        case .c:
            // Combined scale + opacity, longer period.
            if button.layer?.animation(forKey: opacityAnimationKey) == nil {
                let opacity = CABasicAnimation(keyPath: "opacity")
                opacity.fromValue = 0.7
                opacity.toValue = 1.0
                opacity.duration = duration / 2
                opacity.autoreverses = true
                opacity.repeatCount = .infinity
                button.layer?.add(opacity, forKey: opacityAnimationKey)
            }
        }
    }

    private func stopPulse(on button: NSStatusBarButton) {
        button.layer?.removeAnimation(forKey: pulseAnimationKey)
        removeOpacityPulse(on: button)
        button.layer?.transform = CATransform3DIdentity
        button.layer?.opacity = 1
    }

    private func removeOpacityPulse(on button: NSStatusBarButton) {
        button.layer?.removeAnimation(forKey: opacityAnimationKey)
        button.layer?.opacity = 1
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