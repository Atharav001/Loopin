import SwiftUI

/// Focus Interval Alarms surface (V1_IMPROVEMENTS §3): pick ONE fixed interval,
/// then Start/Stop a repeating metronome-style alarm independent of the
/// Pomodoro/Timer window. State persists across relaunch (§3.4).
struct IntervalAlarmsView: View {
    @EnvironmentObject private var engine: FocusIntervalAlarmEngine

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: engine.isRunning ? "bell.badge.fill" : "bell.circle")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.accentViolet)

            Text("Repeating pause reminder")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            intervalPicker

            statusBadge

            toggleButton
        }
        .frame(maxWidth: .infinity)
    }

    /// Fixed preset list from §3.1, rendered as a segmented control.
    private var intervalPicker: some View {
        Picker("Interval", selection: Binding(
            get: { engine.intervalMinutes },
            set: { minutes in
                engine.setInterval(minutes: minutes)
            }
        )) {
            ForEach(FocusIntervalAlarmEngine.intervalChoices, id: \.self) { minutes in
                Text("\(minutes)").tag(minutes)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
        .disabled(engine.isRunning)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(engine.isRunning ? AppTheme.accentViolet : AppTheme.textSecondary.opacity(0.5))
                .frame(width: 7, height: 7)
            Text(engine.isRunning
                ? "Alarm every \(engine.intervalMinutes) min"
                : "Idle — pick an interval and start")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var toggleButton: some View {
        Button {
            engine.isRunning ? engine.stop() : engine.start()
        } label: {
            Label(
                engine.isRunning ? "Stop" : "Start",
                systemImage: engine.isRunning ? "stop.fill" : "play.fill"
            )
            .frame(minWidth: 140)
        }
        .buttonStyle(.borderedProminent)
        .tint(engine.isRunning ? AppTheme.accentCoral : AppTheme.accentViolet)
        .foregroundStyle(Color.black)
    }
}

#Preview {
    IntervalAlarmsView()
        .environmentObject(FocusIntervalAlarmEngine(settingsStore: SettingsStore()))
        .environmentObject(SettingsStore())
        .background(AppTheme.background)
}