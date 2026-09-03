import SwiftUI
import AppKit

/// Pomodoro / Timer / Stopwatch window (V1_IMPROVEMENTS §2). Phase 10 hosts the
/// existing Pomodoro TimerView; the mode switcher lands in Phase 11.
struct TimerWindowView: View {
    @EnvironmentObject private var bridge: PanelBridge

    var body: some View {
        VStack(spacing: 0) {
            WindowHeaderView(title: "Pomodoro / Timer / Stopwatch")
            Divider()
            TimerView()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 320, minHeight: 360)
        .background(AppTheme.background)
        .glow(
            accent: AppTheme.accentViolet,
            intensity: .standard,
            active: bridge.isPinned
        )
    }
}

#Preview {
    TimerWindowView()
        .environmentObject(PanelBridge())
        .environmentObject(TaskStore())
        .environmentObject(SettingsStore())
        .environmentObject(TimerEngine(session: TimerSession()))
        .environmentObject(TimerSession())
}