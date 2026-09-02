import SwiftUI

struct GlowModifier: ViewModifier {
    var accent: Color
    var intensity: StimulationIntensity

    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func glow(accent: Color, intensity: StimulationIntensity = .standard) -> some View {
        modifier(GlowModifier(accent: accent, intensity: intensity))
    }
}