import Foundation

enum RSDSafeCopy {
    static let sessionMissed = "That session didn't happen — want to try a shorter one?"
    static let sessionSkipped = "Skipped. Ready when you are."
    static let taskOverdueLabel = "Still open"
    static let streakBrokenNeutral = "Starting a new streak today"
    static let timerReset = "Reset"
    static let allTasksIncompleteEndOfDay = "A few are still open — they'll be here tomorrow"
}

enum RSDSafeCopyNeutralBadge {
    static let background = "#3A3A40"
    static let text = "#C8C8D0"
}