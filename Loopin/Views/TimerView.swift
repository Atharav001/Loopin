import SwiftUI
import AppKit

/// Timer window body. Hosts a mode switcher (Pomodoro | Timer | Stopwatch,
/// V1_IMPROVEMENTS §2.1) and the three mode UIs.
struct TimerView: View {
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var session: TimerSession
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var taskStore: TaskStore

    /// Timer mode's editable single-duration stepper value (minutes).
    @State private var timerMinutes: Int = 25

    /// Laps recorded by the stopwatch (elapsed seconds at tap). §2.1.
    @State private var laps: [TimeInterval] = []

    /// Pending mode switch when a confirmation is required (§2.2).
    @State private var pendingSwitch: TimerMode?

    /// Flips on phase change to drive the one-shot glow flash (allow-list #3).
    @State private var phaseFlash = false

    // MARK: - Mode

    /// Picker binding into the session mode; intercepts mid-session switches.
    private var modeBinding: Binding<TimerMode> {
        Binding(
            get: { session.mode },
            set: { newMode in
                guard newMode != session.mode else { return }
                if engine.isSessionActive && session.mode != .stopwatch {
                    pendingSwitch = newMode
                } else {
                    engine.switchMode(to: newMode)
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            modeSwitcher

            switch session.mode {
            case .pomodoro:
                pomodoroBody
            case .timer:
                timerBody
            case .stopwatch:
                stopwatchBody
            }
        }
        .padding(.vertical, 6)
        .onChange(of: session.phase) { _, _ in
            phaseFlash.toggle()
        }
        .confirmationDialog(
            "Switch to \(pendingSwitch?.label ?? "")?",
            isPresented: Binding(
                get: { pendingSwitch != nil },
                set: { if !$0 { pendingSwitch = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Switch") {
                if let target = pendingSwitch {
                    engine.switchMode(to: target)
                }
                pendingSwitch = nil
            }
            Button("Keep going", role: .cancel) {
                pendingSwitch = nil
            }
        } message: {
            Text("A timer is running. Switching will discard its progress.")
        }
    }

    // MARK: - Mode switcher

    private var modeSwitcher: some View {
        Picker("Mode", selection: modeBinding) {
            ForEach(TimerMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(maxWidth: 280)
    }

    // MARK: - Pomodoro

    private var pomodoroBody: some View {
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
            pomodoroControls
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

    // MARK: - Timer mode (§2.1)

    private var timerBody: some View {
        VStack(spacing: 12) {
            timerDurationEditor
            ring
            phaseLabel
            timerControls
        }
    }

    /// Stepper for the Timer-mode single countdown. Live-editable: while a
    /// countdown runs, growing the value EXTENDS the remaining time (never
    /// truncates, mirroring FR-6.4); shrinking only affects the next start.
    private var timerDurationEditor: some View {
        HStack(spacing: 8) {
            Text("\(timerMinutes)")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .frame(minWidth: 20)
            Stepper("", value: $timerMinutes, in: 1...480, onEditingChanged: { editing in
                if !editing { applyTimerDurationEdit() }
            })
            .labelsHidden()
            Text("min")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .onAppear {
            if session.timerTotalSeconds > 0 {
                timerMinutes = max(1, Int((session.timerTotalSeconds / 60).rounded()))
            }
        }
    }

    private func applyTimerDurationEdit() {
        let newTotal = TimeInterval(timerMinutes) * 60
        if session.mode == .timer, session.phase == .timer, newTotal > session.timerTotalSeconds {
            let added = newTotal - session.timerTotalSeconds
            session.timerTotalSeconds = newTotal
            session.remainingSeconds += added
        } else {
            session.timerTotalSeconds = newTotal
        }
    }

    private var timerControls: some View {
        HStack(spacing: 10) {
            if session.phase != .timer {
                Button("Start") {
                    engine.startTimer(duration: TimeInterval(timerMinutes) * 60)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentViolet)
                .foregroundStyle(Color.black)
            } else {
                Button(session.isPaused ? "Resume" : "Pause") {
                    session.isPaused ? engine.resume() : engine.pause()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentViolet)
                .foregroundStyle(Color.black)

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

    // MARK: - Stopwatch (§2.1)

    private var stopwatchBody: some View {
        VStack(spacing: 12) {
            Text(stopwatchString)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary)
            HStack(spacing: 10) {
                if !stopwatchRunning {
                    Button("Start") {
                        engine.startStopwatch()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentCoral)
                    .foregroundStyle(Color.black)
                } else {
                    Button(session.isPaused ? "Resume" : "Pause") {
                        session.isPaused ? engine.resume() : engine.pause()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentCoral)
                    .foregroundStyle(Color.black)

                    Button("Lap") {
                        laps.append(session.elapsedSeconds)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    engine.reset()
                    laps = []
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .help(RSDSafeCopy.timerReset)
            }
            if !laps.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(laps.enumerated().reversed()), id: \.offset) { index, elapsed in
                        HStack {
                            Text("Lap \(laps.count - index)")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Text(stopwatchString(timeInterval: elapsed))
                                .font(.system(size: 11))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                }
                .frame(maxWidth: 280)
            }
        }
    }

    private var stopwatchRunning: Bool {
        session.mode == .stopwatch && session.elapsedSeconds > 0
    }

    private var stopwatchString: String {
        stopwatchString(timeInterval: session.elapsedSeconds)
    }

    private func stopwatchString(timeInterval: TimeInterval) -> String {
        let total = Int(timeInterval.rounded())
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Shared ring/label

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.2), lineWidth: 2)

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
        case .timer: return "Countdown"
        case .idle: return "Ready"
        }
    }

    private var accentColor: Color { AppTheme.color(for: session.phase) }

    private var isIdle: Bool { session.phase == .idle }

    private var ringProgress: Double {
        switch session.mode {
        case .pomodoro, .timer:
            let total = currentPhaseTotalSeconds
            guard total > 0 else { return 0 }
            return max(0, min(1, session.remainingSeconds / total))
        case .stopwatch:
            return 0
        }
    }

    private var currentPhaseTotalSeconds: TimeInterval {
        switch session.mode {
        case .timer:
            return session.timerTotalSeconds
        case .pomodoro:
            guard let preset = session.activePreset else { return 0 }
            switch session.phase {
            case .focus: return TimeInterval(preset.focusMinutes) * 60
            case .breakShort: return TimeInterval(preset.breakMinutes) * 60
            case .breakLong: return TimeInterval(preset.longBreakMinutes) * 60
            case .timer, .idle: return 0
            }
        case .stopwatch:
            return 0
        }
    }

    // MARK: - Controls

    private var pomodoroControls: some View {
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

private extension TimerMode {
    var label: String {
        switch self {
        case .pomodoro: return "Pomodoro"
        case .timer: return "Timer"
        case .stopwatch: return "Stopwatch"
        }
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