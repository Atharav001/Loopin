import SwiftUI

/// Focus Interval Alarms surface (V1_IMPROVEMENTS §3). Full implementation
/// (repeating metronome alarm + distinct sound) lands in Phase 12; Phase 10
/// provides the placeholder panel with client state mirrored from settings.
struct IntervalAlarmsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.circle")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.accentViolet)
            Text("Focus Interval Alarms")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(getStatusText())
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Repeating pause reminders, coming in this phase.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func getStatusText() -> String {
        let alarm = settingsStore.settings.focusIntervalAlarm
        let running = alarm.isRunning ? "running" : "idle"
        return "Interval: \(alarm.intervalMinutes) min · \(running)"
    }
}

#Preview {
    IntervalAlarmsView()
        .environmentObject(SettingsStore())
        .background(AppTheme.background)
}