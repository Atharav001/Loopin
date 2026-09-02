import SwiftUI

/// Expanding ripple on trigger (DESIGN §9): a stroke circle scales 0.1x → 2.5x
/// while its opacity fades 0.8 → 0. Duration scales with stimulation intensity.
struct RippleModifier: ViewModifier {
    var trigger: Bool
    var intensity: StimulationIntensity
    var color: Color

    @State private var rippleScale: CGFloat = 0.1
    @State private var rippleOpacity: Double = 0

    private var duration: Double {
        switch intensity {
        case .gentle: return 0.5
        case .standard: return 0.65
        case .high: return 0.8
        }
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if rippleOpacity > 0 {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .scaleEffect(rippleScale)
                        .opacity(rippleOpacity)
                }
            }
            .onChange(of: trigger) { _, fired in
                guard fired else { return }
                rippleScale = 0.1
                rippleOpacity = 0.8
                withAnimation(.easeOut(duration: duration)) {
                    rippleScale = 2.5
                    rippleOpacity = 0
                }
            }
    }
}

extension View {
    func ripple(trigger: Bool, intensity: StimulationIntensity = .standard, color: Color = AppTheme.accentTeal) -> some View {
        modifier(RippleModifier(trigger: trigger, intensity: intensity, color: color))
    }
}