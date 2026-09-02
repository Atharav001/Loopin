import SwiftUI
import AppKit

struct TimerView: View {
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var session: TimerSession
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var taskStore: TaskStore

    private var ringProgress: Double {
        // Shrinking disc: starts full, drains to nothing as time elapses.
        guard session.activePreset != nil else { return 0 }
        let total = currentPhaseTotalSeconds
        guard total > 0 else { return 0 }
        return max(0, min(1, session.remainingSeconds / total))
    }

    private var currentPhaseTotalSeconds: TimeInterval {
        guard let preset = session.activePreset else { return 0 }
        switch session.phase {
        case .focus: return TimeInterval(preset.focusMinutes) * 60
        case .breakShort: return TimeInterval(preset.breakMinutes) * 60
        case .breakLong: return TimeInterval(preset.longBreakMinutes) * 60
        case .idle: return 0
        }
    }

    private var isIdle: Bool { session.phase == .idle }

    private var accentColor: Color {
        switch session.phase {
        case .focus: return Color(hex: "#3DDC97")
        case .breakShort, .breakLong: return Color(hex: "#FF7A6B")
        case .idle: return Color(nsColor: .secondaryLabelColor)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            presetPicker
            ring
            if let linkedTitle = linkedTaskTitle {
                Text(linkedTitle)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
            phaseLabel
            controls
        }
        .padding(.vertical, 6)
    }

    private var presetPicker: some View {
        Picker("Preset", selection: Binding(
            get: { session.activePreset?.id },
            set: { newID in
                guard let id = newID else { return }
                selectPreset(id: id)
            }
        )) {
            ForEach(settingsStore.settings.presets) { preset in
                Text(preset.name).tag(Optional(preset.id))
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(maxWidth: 280)
    }

    private var ring: some View {
        ZStack {
            // Static outer ring, 2pt @ 20% opacity.
            Circle()
                .stroke(accentColor.opacity(0.2), lineWidth: 2)

            // Shrinking progress arc, 4pt full opacity.
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: session.remainingSeconds)

            Text(timeString(seconds: session.remainingSeconds))
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(nsColor: isIdle ? .secondaryLabelColor : .labelColor))
        }
        .frame(width: 132, height: 132)
        .padding(8)
        .glow(accent: accentColor, intensity: settingsStore.settings.stimulationIntensity, active: !isIdle)
    }

    private var phaseLabel: some View {
        Text(phaseName)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(accentColor)
    }

    private var phaseName: String {
        switch session.phase {
        case .focus: return "Focus"
        case .breakShort: return "Break"
        case .breakLong: return "Long break"
        case .idle: return "Ready"
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 10) {
            if isIdle {
                Button("Start focus") {
                    engine.startFocus()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#3DDC97"))
                .foregroundStyle(Color.black)
            } else {
                Button(session.isPaused ? "Resume" : "Pause") {
                    session.isPaused ? engine.resume() : engine.pause()
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .foregroundStyle(Color.black)

                Button("Skip") {
                    engine.skip()
                }
                .buttonStyle(.bordered)
                .help(RSDSafeCopy.sessionSkipped)

                Button {
                    engine.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .help(RSDSafeCopy.timerReset)
            }
        }
    }

    private var linkedTaskTitle: String? {
        guard let id = session.linkedTaskId else { return nil }
        return taskStore.tasks.first(where: { $0.id == id })?.title
    }

    private func selectPreset(id: UUID) {
        guard let preset = settingsStore.settings.presets.first(where: { $0.id == id }) else { return }
        session.activePreset = preset
        engine.synchronizeWithPreset()
    }

    private func timeString(seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    TimerEnvWrapper()
}

private struct TimerEnvWrapper: View {
    let session = TimerSession()
    var body: some View {
        TimerView()
            .environmentObject(TimerEngine(session: session))
            .environmentObject(session)
            .environmentObject(SettingsStore())
            .environmentObject(TaskStore())
            .padding()
    }
}