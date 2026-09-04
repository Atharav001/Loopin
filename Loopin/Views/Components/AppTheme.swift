import SwiftUI

/// Central palette matching Memorigi Android app aesthetics (Deep Midnight + Vibrant Accents).
enum AppTheme {
    static let background = Color(hex: "#0D0F17")       // Memorigi deep midnight
    static let surface = Color(hex: "#161928")          // Memorigi container surface
    static let cardBackground = Color(hex: "#1E2235")   // Memorigi task card surface
    static let borderSubtle = Color(hex: "#2A2F4A")     // Card border outline

    static let textPrimary = Color(hex: "#F5F6FA")
    static let textSecondary = Color(hex: "#8E95B3")

    static let accentTeal = Color(hex: "#06B6D4")       // Memorigi Cyan Teal
    static let accentViolet = Color(hex: "#8B5CF6")     // Memorigi Electric Violet
    static let accentCoral = Color(hex: "#EC4899")      // Memorigi Neon Pink / Coral
    static let accentAmber = Color(hex: "#F59E0B")      // Memorigi Warm Amber
    static let accentGreen = Color(hex: "#10B981")      // Memorigi Emerald Green

    static let neutralBadgeBackground = Color(hex: "#282C44")
    static let neutralBadgeText = Color(hex: "#B0B7D0")

    static func color(for phase: TimerPhase) -> Color {
        switch phase {
        case .focus: return accentTeal
        case .breakShort, .breakLong: return accentCoral
        case .timer: return accentViolet
        case .idle: return textSecondary
        }
    }

    /// Color for a task's color tag matching Memorigi list categories.
    static func color(for tag: TaskColorTag) -> Color {
        switch tag {
        case .teal: return accentTeal
        case .coral: return accentCoral
        case .violet: return accentViolet
        case .amber: return accentAmber
        case .neutral: return textSecondary
        }
    }
}