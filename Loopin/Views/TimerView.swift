import SwiftUI
import AppKit

struct TimerView: View {
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var session: TimerSession
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var taskStore: TaskStore

    /// Flips on phase change to drive the one-shot glow flash (allow-list #3).
    @State private var phaseFlash = false

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

    private var accentColor: Color { AppTheme.color(for: session.phase) }

    var body: some View {
        VStack(spacing: 12) {
            presetPicker
            ZStack {
                ring
                presenceGlow
            }
            if let linked = linkedTask {
                VStack(spacing: 2) {
                    if let step = linked.firstStep, !step.isEmpty {
                        Text(step)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.accentTeal)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Text(linked.title)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            phaseLabel
            controls
        }
        .padding(.vertical, 6)
        .onChange(of: session.phase) { _, _ in
            phaseFlash.toggle()
        }
    }

    private var presenceGlow: some View {
        Group {
            if session.phase == .focus && !session.isPaused {
                PresenceGlowView()
            }
        }
    }

    private var linkedTask: Task? {
        guard let id = session.linkedTaskId else { return nil }
        return taskStore.tasks.first(where: { $0.id == id })
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
                .foregroundStyle(isIdle ? AppTheme.textSecondary : AppTheme.textPrimary)
        }
        .frame(width: 132, height: 132)
        .padding(8)
        .glow(
            accent: accentColor,
            intensity: settingsStore.settings.stimulationIntensity,
            active: !isIdle
        )
        .ripple(trigger: phaseFlash, color: accentColor)
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
                    engine.startFocus(linkedTaskId: suggestedLinkedTaskID)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentTeal)
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

    /// FR-13: when starting a fresh focus session with no task already linked,
    /// surface a task framed "do first next session" as the session's linked task.
    private var suggestedLinkedTaskID: UUID? {
        taskStore.tasks
            .first(where: { !$0.isComplete && $0.framing == .doFirstNextSession })?
            .id
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