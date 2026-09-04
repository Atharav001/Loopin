import SwiftUI

/// Central palette matching premium dark vibrant design system (Deep Cosmic Midnight + Vivid Neon Accents).
enum AppTheme {
    static let background = Color(hex: "#090A10")       // Deep cosmic obsidian
    static let surface = Color(hex: "#121422")          // Container surface
    static let surfaceElevated = Color(hex: "#16192B")  // Floating elevated surface
    static let cardBackground = Color(hex: "#191C30")   // Task card surface
    static let cardBackgroundHover = Color(hex: "#20243C") // Hover card surface
    static let borderSubtle = Color(hex: "#262B48")     // Card border outline

    static let textPrimary = Color(hex: "#F8F9FE")
    static let textSecondary = Color(hex: "#949CB8")

    static let accentTeal = Color(hex: "#00E5FF")       // Neon Electric Cyan
    static let accentViolet = Color(hex: "#A855F7")     // Vivid Cyber Purple
    static let accentCoral = Color(hex: "#F43F5E")      // Neon Rose / Coral
    static let accentAmber = Color(hex: "#FBBF24")      // Radiant Amber / Gold
    static let accentGreen = Color(hex: "#10B981")      // Vivid Emerald
    static let accentBlue = Color(hex: "#3B82F6")       // Sapphire Blue

    static let neutralBadgeBackground = Color(hex: "#222740")
    static let neutralBadgeText = Color(hex: "#CBD5E1")

    // Glow Gradient Presets
    static let glowGradientCyan = LinearGradient(
        colors: [Color(hex: "#00E5FF"), Color(hex: "#A855F7"), Color(hex: "#F43F5E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glowGradientViolet = LinearGradient(
        colors: [Color(hex: "#A855F7"), Color(hex: "#F43F5E"), Color(hex: "#FBBF24")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glowGradientCoral = LinearGradient(
        colors: [Color(hex: "#F43F5E"), Color(hex: "#FBBF24"), Color(hex: "#00E5FF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func color(for phase: TimerPhase) -> Color {
        switch phase {
        case .focus: return accentTeal
        case .breakShort, .breakLong: return accentCoral
        case .timer: return accentViolet
        case .idle: return textSecondary
        }
    }

    /// Color for a task's color tag matching vibrant category accents.
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