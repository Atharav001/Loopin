import SwiftUI

/// FR-16: solo focus-companion presence cue (DESIGN §14).
/// A steady, slow-breathing violet glow around the timer that reads as calm
/// ambient companionship — NOT a reminder pulse (FR-7) and NOT a character.
///
/// Deliberately NOT scaled by `stimulationIntensity`: presence should always be
/// quiet, never amplified toward "high", or it would defeat its purpose.
/// Rendered only by `TimerView` while a focus session is running and unpaused.
struct PresenceGlowView: View {
    @State private var breathe = false

    var body: some View {
        Circle()
            .stroke(
                AppTheme.accentViolet,
                lineWidth: 3
            )
            .frame(width: 142, height: 142)
            .opacity(breathe ? 0.75 : 0.5)
            .animation(
                .easeInOut(duration: 4).repeatForever(autoreverses: true),
                value: breathe
            )
            .allowsHitTesting(false)
            .onAppear { breathe = true }
    }
}

#Preview {
    ZStack {
        PresenceGlowView()
            .padding()
    }
    .frame(width: 200, height: 200)
    .background(AppTheme.background)
}