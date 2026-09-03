import AppKit
import Combine

enum MenuBarIconState {
    case idle
    case focusRunning
    case breakRunning
}

/// Menu bar item. Clicking it now opens an NSMenu picker (V1_IMPROVEMENTS §1.1)
/// that forwards to one of several independent windows, not a single panel.
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

        let menu = buildMenu()
        statusItem.menu = menu
        button.action = nil  // The menu is attached to the status item directly.
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(menuItem(title: "To-Do List", kind: .todo))
        menu.addItem(menuItem(title: "Pomodoro / Timer / Stopwatch", kind: .timer))
        menu.addItem(menuItem(title: "Focus Interval Alarms", kind: .alarms))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Settings", kind: .settings))
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Loopin", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private func menuItem(title: String, kind: WindowKind) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: #selector(selectWindow(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = kind
        return item
    }

    @objc private func selectWindow(_ sender: NSMenuItem) {
        guard let kind = sender.representedObject as? WindowKind else { return }
        panelController.focus(kind)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// Brief, self-clearing pulse shown when a Focus Interval Alarm fires
    /// (§3.3 "menu bar pulse" component of the attention system). Independent of
    /// the Pomodoro reminder's `reminderPending` pulse.
    func pulseForAlarm() {
        guard let button = statusItem.button else { return }
        button.image?.isTemplate = false
        button.contentTintColor = NSColor(hex: "#9B7BFF") // Accent Violet
        startPulse(on: button, variant: .c)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self else { return }
            if !self.timerSession.reminderPending {
                self.refreshIcon()
            } else {
                self.stopPulse(on: button)
                button.image?.isTemplate = false
                button.contentTintColor = NSColor(hex: "#3DDC97")
            }
        }
    }

    func refreshIcon() {
        let pending = timerSession.reminderPending
        switch timerSession.phase {
        case .focus, .timer:
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