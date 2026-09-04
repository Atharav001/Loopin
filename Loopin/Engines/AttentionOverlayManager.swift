import SwiftUI
import AppKit
import UserNotifications

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
        case .breakEnded: return "☕️"
        case .alarmFired: return "🎯"
        case .timerEnded: return "⏰"
        case .taskCompleted: return "✨"
        }
    }

    var title: String {
        switch self {
        case .focusEnded: return "FOCUS SESSION COMPLETED"
        case .breakEnded: return "BREAK ENDED — READY TO RESUME?"
        case .alarmFired: return "FOCUS INTERVAL CHECK-IN"
        case .timerEnded: return "TIMER COUNTDOWN COMPLETE"
        case .taskCompleted: return "GREAT JOB! TASK COMPLETED"
        }
    }

    var subtitle: String {
        switch self {
        case .focusEnded: return "Step back, take a breath, and give your mind a quick rest."
        case .breakEnded: return "Time to return to your workspace and pick up where you left off."
        case .alarmFired: return "Gentle reminder: check your active task and stay locked in."
        case .timerEnded: return "Your scheduled timer has elapsed."
        case .taskCompleted: return "Dopamine unlocked! Keep your momentum going."
        }
    }

    var primaryColor: Color {
        switch self {
        case .focusEnded: return AppTheme.accentTeal
        case .breakEnded: return AppTheme.accentCoral
        case .alarmFired: return AppTheme.accentViolet
        case .timerEnded: return AppTheme.accentAmber
        case .taskCompleted: return AppTheme.accentGreen
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .alarmFired:
            return [AppTheme.accentViolet, AppTheme.accentTeal, AppTheme.accentAmber, AppTheme.accentViolet]
        case .taskCompleted:
            return [AppTheme.accentGreen, AppTheme.accentTeal, AppTheme.accentViolet, AppTheme.accentGreen]
        case .focusEnded:
            return [AppTheme.accentTeal, AppTheme.accentViolet, AppTheme.accentAmber, AppTheme.accentTeal]
        case .breakEnded:
            return [AppTheme.accentCoral, AppTheme.accentAmber, AppTheme.accentViolet, AppTheme.accentCoral]
        case .timerEnded:
            return [AppTheme.accentAmber, AppTheme.accentCoral, AppTheme.accentViolet, AppTheme.accentAmber]
        }
    }
}

/// Borderless overlay window rendered over full-screen apps and spaces.
final class AttentionOverlayWindow: NSWindow {
    init(screen: NSScreen, event: AttentionEventType) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.isReleasedWhenClosed = false
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
        self.hasShadow = false
        self.contentView = NSHostingView(rootView: AttentionOverlayView(event: event))
    }
}

/// Live multi-color animated progressive glow entering from behind screen edges + high-clarity notification banner.
struct AttentionOverlayView: View {
    let event: AttentionEventType

    @State private var isVisible = false
    @State private var pulseIntensity: CGFloat = 0.5
    @State private var rotationDegrees: Double = 0
    @State private var edgeBleedInward: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            // MARK: 1. Ambient Light Bleed (Entering from behind physical screen edges)
            ZStack {
                // Top edge light pouring down
                LinearGradient(
                    colors: [event.primaryColor.opacity(pulseIntensity * 0.7), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120 + edgeBleedInward)
                .frame(maxHeight: .infinity, alignment: .top)

                // Bottom edge light pouring up
                LinearGradient(
                    colors: [event.primaryColor.opacity(pulseIntensity * 0.7), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 120 + edgeBleedInward)
                .frame(maxHeight: .infinity, alignment: .bottom)

                // Leading edge light pouring right
                LinearGradient(
                    colors: [event.primaryColor.opacity(pulseIntensity * 0.7), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 120 + edgeBleedInward)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Trailing edge light pouring left
                LinearGradient(
                    colors: [event.primaryColor.opacity(pulseIntensity * 0.7), Color.clear],
                    startPoint: .trailing,
                    endPoint: .leading
                )
                .frame(width: 120 + edgeBleedInward)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .ignoresSafeArea()
            .opacity(isVisible ? 1.0 : 0.0)

            // MARK: 2. Live Rotating Multi-Color Progressive Edge Glow
            ZStack {
                // Outermost deep bloom
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        AngularGradient(
                            colors: event.gradientColors,
                            center: .center,
                            angle: .degrees(rotationDegrees)
                        ),
                        lineWidth: 32
                    )
                    .blur(radius: 40)
                    .opacity(pulseIntensity * 0.9)

                // Mid-layer vibrant neon aura
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        AngularGradient(
                            colors: event.gradientColors,
                            center: .center,
                            angle: .degrees(rotationDegrees + 90)
                        ),
                        lineWidth: 14
                    )
                    .blur(radius: 14)
                    .opacity(pulseIntensity * 0.95)

                // Crisp laser inner edge
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        AngularGradient(
                            colors: event.gradientColors,
                            center: .center,
                            angle: .degrees(rotationDegrees)
                        ),
                        lineWidth: 3.5
                    )
                    .opacity(0.9)
            }
            .padding(6)
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 1.02)

            // MARK: 3. Clear, High-Contrast Notification Card (Top-Center)
            HStack(spacing: 16) {
                // Glowing Icon Badge
                ZStack {
                    Circle()
                        .fill(event.primaryColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .strokeBorder(event.primaryColor, lineWidth: 1.5)
                        )
                        .shadow(color: event.primaryColor.opacity(0.6), radius: 8)

                    Text(event.emoji)
                        .font(.system(size: 22))
                }

                // Informative Text
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(event.title)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(event.primaryColor)
                            .tracking(0.6)

                        Text("• Loopin")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Text(event.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: 520)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.surfaceElevated.opacity(0.96))
                    .shadow(color: .black.opacity(0.7), radius: 24, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [event.primaryColor, event.primaryColor.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .offset(y: isVisible ? 44 : -100)
            .opacity(isVisible ? 1.0 : 0.0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Progressive reveal animation: light sweeps in from edges
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                isVisible = true
                edgeBleedInward = 40
            }

            // Continuous smooth rotation for live changing colors
            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) {
                rotationDegrees = 360
            }

            // Rhythmic breathing pulse
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseIntensity = 1.0
            }

            // Smooth exit before window dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
                withAnimation(.easeIn(duration: 0.4)) {
                    isVisible = false
                    edgeBleedInward = 0
                }
            }
        }
    }
}

/// Orchestrates multi-monitor full-screen attention overlays and notification cues.
final class AttentionOverlayManager {
    static let shared = AttentionOverlayManager()
    private var activeWindows: [AttentionOverlayWindow] = []
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    func trigger(event: AttentionEventType, stimulationIntensity: StimulationIntensity = .standard) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // 1. Play calm, soothing audio cue
            switch event {
            case .alarmFired:
                AttentionSoundPlayer.shared.playAlarmBell()
            case .focusEnded, .breakEnded, .timerEnded, .taskCompleted:
                if stimulationIntensity != .gentle {
                    AttentionSoundPlayer.shared.playCycleEndChime()
                }
            }

            // 2. Post native user notification so user knows what occurred
            self.postNotification(for: event)

            // 3. Request user attention
            NSApp.requestUserAttention(.informationalRequest)

            // 4. Dismiss existing overlay windows
            self.dismissWindows()

            // 5. Spawn live glowing overlay window across all screens
            let screens = NSScreen.screens
            let windows = screens.map { screen in
                AttentionOverlayWindow(screen: screen, event: event)
            }

            for win in windows {
                win.orderFrontRegardless()
            }
            self.activeWindows = windows

            // 6. Auto-dismiss safely after 4.4s
            let work = DispatchWorkItem { [weak self] in
                self?.dismissWindows()
            }
            self.dismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.4, execute: work)
        }
    }

    private func postNotification(for event: AttentionEventType) {
        let content = UNMutableNotificationContent()
        content.title = "\(event.emoji) \(event.title)"
        content.body = event.subtitle
        content.sound = nil // Sound played via AttentionSoundPlayer

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func dismissWindows() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        for win in activeWindows {
            win.orderOut(nil)
        }
        activeWindows.removeAll()
    }
}
