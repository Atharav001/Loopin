import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                generalSection
                timersSection
                remindersSection
            }
            .padding(16)
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("General")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Toggle("Pin panel by default", isOn: $settingsStore.settings.pinnedByDefault)
            Toggle("Daily scope cap (1-3-5)", isOn: $settingsStore.settings.dailyCapEnabled)

            VStack(alignment: .leading, spacing: 6) {
                Text("Stimulation intensity")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Picker("", selection: $settingsStore.settings.stimulationIntensity) {
                    ForEach(StimulationIntensity.allCases, id: \.self) { level in
                        Text(level.rawValue.capitalized).tag(level)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Timer presets

    private var timersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focus timers")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach($settingsStore.settings.presets) { $preset in
                presetEditor($preset)
            }
        }
    }

    private func presetEditor(_ preset: Binding<TimerPreset>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Preset name", text: preset.name)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            HStack(spacing: 14) {
                durationField(label: "Focus", value: preset.focusMinutes, range: 5...120)
                durationField(label: "Break", value: preset.breakMinutes, range: 1...30)
                durationField(label: "Long break", value: preset.longBreakMinutes, range: 5...60)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.surface)
        )
    }

    private func durationField(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue) min")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reminders")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            HStack {
                Text("Escalation delay")
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Stepper(value: $settingsStore.settings.reminderEscalationDelaySeconds, in: 5...300, step: 5) {
                    Text("\(Int(settingsStore.settings.reminderEscalationDelaySeconds))s")
                        .monospacedDigit()
                }
            }

            HStack {
                Text("Snooze length")
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Stepper(value: $settingsStore.settings.snoozeLengthMinutes, in: 1...30) {
                    Text("\(settingsStore.settings.snoozeLengthMinutes) min")
                        .monospacedDigit()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsStore())
        .frame(width: 400, height: 500)
        .background(AppTheme.background)
}