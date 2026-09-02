import SwiftUI

struct RippleModifier: ViewModifier {
    var trigger: Bool
    var intensity: StimulationIntensity

    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func ripple(trigger: Bool, intensity: StimulationIntensity = .standard) -> some View {
        modifier(RippleModifier(trigger: trigger, intensity: intensity))
    }
}