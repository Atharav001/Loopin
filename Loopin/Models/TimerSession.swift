import Foundation
import Combine

enum TimerPhase: String, Codable, Equatable {
    case focus
    case breakShort
    case breakLong
    case idle
    /// Timer mode's single countdown (V1_IMPROVEMENTS §2.1).
    case timer
}

/// Timer window mode (V1_IMPROVEMENTS §2.1).
enum TimerMode: String, Codable, Equatable, CaseIterable, Identifiable {
    case pomodoro
    case timer
    case stopwatch

    var id: String { rawValue }
}

final class TimerSession: ObservableObject {
    @Published var phase: TimerPhase = .idle
    @Published var remainingSeconds: TimeInterval = 0
    @Published var isPaused: Bool = false
    @Published var completedFocusCyclesToday: Int = 0
    @Published var activePreset: TimerPreset?
    @Published var linkedTaskId: UUID?
    @Published var mode: TimerMode = .pomodoro
    /// Timer-mode total duration (single countdown), set on start.
    @Published var timerTotalSeconds: TimeInterval = 0
    /// Stopwatch-mode count-up elapsed time.
    @Published var elapsedSeconds: TimeInterval = 0

    /// True while a reminder is pending acknowledgment (Stage 1 of escalation).
    @Published var reminderPending: Bool = false
}