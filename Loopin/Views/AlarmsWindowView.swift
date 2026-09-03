import SwiftUI
import AppKit

/// Focus Interval Alarms window (V1_IMPROVEMENTS §3). Full feature lands in
/// Phase 12; Phase 10 hosts a minimal placeholder surface with the same chrome.
struct AlarmsWindowView: View {
    @EnvironmentObject private var bridge: PanelBridge
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            WindowHeaderView(title: "Focus Interval Alarms")
            Divider()
            IntervalAlarmsView()
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 320, minHeight: 260)
        .background(AppTheme.background)
        .glow(
            accent: AppTheme.accentViolet,
            intensity: .standard,
            active: bridge.isPinned
        )
    }
}

#Preview {
    AlarmsWindowView()
        .environmentObject(PanelBridge())
        .environmentObject(SettingsStore())
        .environmentObject(TaskStore())
        .environmentObject(TimerEngine(session: TimerSession()))
        .environmentObject(TimerSession())
        .environmentObject(FocusIntervalAlarmEngine(settingsStore: SettingsStore()))
}