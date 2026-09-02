import SwiftUI

struct GlowModifier: ViewModifier {
    var accent: Color
    var intensity: StimulationIntensity
    var active: Bool

    private var doubleShadow: Double {
        switch intensity {
        case .gentle: return 4.0
        case .standard: return 6.0
        case .high: return 10.0
        }
    }

    private var wideShadow: Double {
        switch intensity {
        case .gentle: return 12.0
        case .standard: return 18.0
        case .high: return 28.0
        }
    }

    private var opacity: Double {
        switch intensity {
        case .gentle: return 0.35
        case .standard: return 0.55
        case .high: return 0.8
        }
    }

    func body(content: Content) -> some View {
        if active {
            content
                .shadow(color: accent.opacity(opacity), radius: doubleShadow)
                .shadow(color: accent.opacity(opacity), radius: wideShadow)
        } else {
            content
        }
    }
}

extension View {
    func glow(accent: Color, intensity: StimulationIntensity = .standard, active: Bool = true) -> some View {
        modifier(GlowModifier(accent: accent, intensity: intensity, active: active))
    }
}