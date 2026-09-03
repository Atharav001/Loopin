import SwiftUI
import AppKit

/// Event type for full-screen attention overlay triggers (V1_IMPROVEMENTS §6.4).
enum AttentionEventType {
    case focusEnded
    case breakEnded
    case alarmFired
    case timerEnded

    var title: String {
        switch self {
        case .focusEnded: return "Focus session done"
        case .breakEnded: return "Break's over — ready when you are"
        case .alarmFired: return "Interval check-in"
        case .timerEnded: return "Time's up"
        }
    }

    var glowColor: Color {
        switch self {
        case .focusEnded: return AppTheme.accentTeal
        case .breakEnded: return AppTheme.accentCoral
        case .alarmFired: return AppTheme.accentViolet
        case .timerEnded: return AppTheme.accentTeal
        }
    }
}

/// Borderless overlay window rendered over full-screen apps (§6.3).
final class AttentionOverlayWindow: NSWindow {
    init(screen: NSScreen, event: AttentionEventType) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // §6.5 checklist:
        self.level = .screenSaver // Renders above full-screen spaces
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true // CRITICAL: click-through, never intercepts input
        self.hasShadow = false
        self.contentView = NSHostingView(rootView: AttentionOverlayView(event: event))
    }
}

/// SwiftUI visual effect: inset screen-edge glow + sliding message card (§6.4).
struct AttentionOverlayView: View {
    let event: AttentionEventType
    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .top) {
            // 1. Edge glow inset from four edges
            RoundedRectangle(cornerRadius: 16)
                .stroke(event.glowColor.opacity(0.85), lineWidth: 12)
                .shadow(color: event.glowColor.opacity(0.9), radius: 24, x: 0, y: 0)
                .blur(radius: 4)
                .padding(12)
                .opacity(isVisible ? 1 : 0)

            // 2. Sliding message pill card (top-center)
            HStack(spacing: 8) {
                Circle()
                    .fill(event.glowColor)
                    .frame(width: 8, height: 8)
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(AppTheme.surface)
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                    .overlay(
                        Capsule()
                            .strokeBorder(event.glowColor.opacity(0.5), lineWidth: 1)
                    )
            )
            .offset(y: isVisible ? 28 : -60)
            .opacity(isVisible ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                isVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeIn(duration: 0.35)) {
                    isVisible = false
                }
            }
        }
    }
}

/// Orchestrates multi-monitor full-screen attention overlays (§6.3–6.4).
final class AttentionOverlayManager {
    static let shared = AttentionOverlayManager()
    private var activeWindows: [AttentionOverlayWindow] = []
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    func trigger(event: AttentionEventType, stimulationIntensity: StimulationIntensity = .standard) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Audio & Dock bounce per §6.4
            switch event {
            case .alarmFired:
                // §3.3 & §6.4: Focus Interval Alarms ALWAYS play distinct louder bell
                AttentionSoundPlayer.shared.playAlarmBell()
            case .focusEnded, .breakEnded, .timerEnded:
                if stimulationIntensity != .gentle {
                    AttentionSoundPlayer.shared.playCycleEndChime()
                }
            }
            NSApp.requestUserAttention(.informationalRequest)

            // Dismiss any pre-existing overlay windows
            self.dismissWindows()

            // Spawn one overlay window per active screen (§6.3)
            let screens = NSScreen.screens
            let windows = screens.map { screen in
                AttentionOverlayWindow(screen: screen, event: event)
            }

            for win in windows {
                win.orderFrontRegardless()
            }
            self.activeWindows = windows

            // Auto-dismiss after 3.2s duration
            let work = DispatchWorkItem { [weak self] in
                self?.dismissWindows()
            }
            self.dismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: work)
        }
    }

    private func dismissWindows() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        for win in activeWindows {
            win.close()
        }
        activeWindows.removeAll()
    }
}
