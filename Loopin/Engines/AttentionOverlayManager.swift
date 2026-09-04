import SwiftUI
import AppKit

/// Event type for full-screen attention overlay triggers (ADHD Visual Attention System).
enum AttentionEventType {
    case focusEnded
    case breakEnded
    case alarmFired
    case timerEnded
    case taskCompleted

    var emoji: String {
        switch self {
        case .focusEnded: return "⚡"
        case .breakEnded: return "🚀"
        case .alarmFired: return "🔔"
        case .timerEnded: return "⏰"
        case .taskCompleted: return "🎉"
        }
    }

    var title: String {
        switch self {
        case .focusEnded: return "FOCUS SESSION COMPLETED!"
        case .breakEnded: return "BREAK HAS ENDED — READY?"
        case .alarmFired: return "FOCUS INTERVAL CHECK-IN"
        case .timerEnded: return "TIMER COUNTDOWN FINISHED"
        case .taskCompleted: return "GREAT JOB! TASK COMPLETED"
        }
    }

    var subtitle: String {
        switch self {
        case .focusEnded: return "Take a 10-minute break to recharge ☕️"
        case .breakEnded: return "Time to get back to work and crush your next task!"
        case .alarmFired: return "Refocus on your current task — stay on target 🎯"
        case .timerEnded: return "Your set time duration has elapsed."
        case .taskCompleted: return "Dopamine unlocked! Keep the momentum going."
        }
    }

    var glowColor: Color {
        switch self {
        case .focusEnded: return AppTheme.accentTeal
        case .breakEnded: return AppTheme.accentCoral
        case .alarmFired: return AppTheme.accentViolet
        case .timerEnded: return AppTheme.accentAmber
        case .taskCompleted: return AppTheme.accentGreen
        }
    }
}

/// Borderless overlay window rendered over full-screen apps (YouTube, media players, browser).
final class AttentionOverlayWindow: NSWindow {
    init(screen: NSScreen, event: AttentionEventType) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver // Renders ABOVE full-screen applications & spaces
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true // Click-through, never blocks input or typing
        self.hasShadow = false
        self.contentView = NSHostingView(rootView: AttentionOverlayView(event: event))
    }
}

/// SwiftUI visual effect: Inset multi-layer screen-edge neon glow + top sliding banner card.
struct AttentionOverlayView: View {
    let event: AttentionEventType
    @State private var isVisible = false
    @State private var pulseGlow = false

    var body: some View {
        ZStack(alignment: .top) {
            // 1. Multi-layered Screen-Edge Pulsing Neon Glow
            ZStack {
                // Outer intense border glow
                RoundedRectangle(cornerRadius: 20)
                    .stroke(event.glowColor.opacity(pulseGlow ? 0.95 : 0.4), lineWidth: 16)
                    .shadow(color: event.glowColor.opacity(pulseGlow ? 1.0 : 0.6), radius: 36, x: 0, y: 0)
                    .blur(radius: 6)

                // Inner sharp accent outline
                RoundedRectangle(cornerRadius: 20)
                    .stroke(event.glowColor, lineWidth: 4)
            }
            .padding(10)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1.0 : 1.02)

            // 2. Unmissable Sliding Message Card (Top-Center)
            HStack(spacing: 12) {
                Text(event.emoji)
                    .font(.system(size: 26))
                    .scaleEffect(pulseGlow ? 1.15 : 1.0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(event.glowColor)
                        .tracking(0.5)

                    Text(event.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(AppTheme.background)
                    .shadow(color: .black.opacity(0.6), radius: 14, x: 0, y: 6)
                    .overlay(
                        Capsule()
                            .strokeBorder(event.glowColor.opacity(0.8), lineWidth: 2)
                    )
            )
            .offset(y: isVisible ? 36 : -80)
            .opacity(isVisible ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isVisible = true
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
                withAnimation(.easeIn(duration: 0.4)) {
                    isVisible = false
                }
            }
        }
    }
}

/// Orchestrates multi-monitor full-screen attention overlays across macOS.
final class AttentionOverlayManager {
    static let shared = AttentionOverlayManager()
    private var activeWindows: [AttentionOverlayWindow] = []
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    func trigger(event: AttentionEventType, stimulationIntensity: StimulationIntensity = .standard) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Audio chime & critical Dock icon bounce
            switch event {
            case .alarmFired:
                AttentionSoundPlayer.shared.playAlarmBell()
            case .focusEnded, .breakEnded, .timerEnded, .taskCompleted:
                if stimulationIntensity != .gentle {
                    AttentionSoundPlayer.shared.playCycleEndChime()
                }
            }
            // Request critical user attention so Dock bounces continuously
            NSApp.requestUserAttention(.criticalRequest)

            // Dismiss existing overlay windows
            self.dismissWindows()

            // Spawn overlay window per active screen
            let screens = NSScreen.screens
            let windows = screens.map { screen in
                AttentionOverlayWindow(screen: screen, event: event)
            }

            for win in windows {
                win.orderFrontRegardless()
            }
            self.activeWindows = windows

            // Auto-dismiss after 4.0s duration
            let work = DispatchWorkItem { [weak self] in
                self?.dismissWindows()
            }
            self.dismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: work)
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

