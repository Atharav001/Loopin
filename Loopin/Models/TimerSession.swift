import Foundation
import Combine

enum TimerPhase: String, Codable, Equatable {
    case focus
    case breakShort
    case breakLong
    case idle
}

final class TimerSession: ObservableObject {
    @Published var phase: TimerPhase = .idle
    @Published var remainingSeconds: TimeInterval = 0
    @Published var isPaused: Bool = false
    @Published var completedFocusCyclesToday: Int = 0
    @Published var activePreset: TimerPreset?
    @Published var linkedTaskId: UUID?

    /// True while a reminder is pending acknowledgment (Stage 1 of escalation).
    @Published var reminderPending: Bool = false
}