import SwiftUI

/// Central palette (DESIGN §9). Dark-first.
enum AppTheme {
    static let background = Color(hex: "#121214")
    static let surface = Color(hex: "#1B1B1F")
    static let textPrimary = Color(hex: "#F2F2F5")
    static let textSecondary = Color(hex: "#9A9AA2")

    static let accentTeal = Color(hex: "#3DDC97")     // Focus / pin default
    static let accentCoral = Color(hex: "#FF7A6B")    // Break / reminder B
    static let accentViolet = Color(hex: "#9B7BFF")   // Reminder C / pin-engaged

    static let neutralBadgeBackground = Color(hex: "#3A3A40")
    static let neutralBadgeText = Color(hex: "#C8C8D0")

    static func color(for phase: TimerPhase) -> Color {
        switch phase {
        case .focus: return accentTeal
        case .breakShort, .breakLong: return accentCoral
        case .idle: return textSecondary
        }
    }
}