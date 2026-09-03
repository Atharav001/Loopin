import SwiftUI
import AppKit

/// Settings window (V1_IMPROVEMENTS §1). Standalone window hosting SettingsView.
struct SettingsWindowView: View {
    @EnvironmentObject private var bridge: PanelBridge

    var body: some View {
        VStack(spacing: 0) {
            WindowHeaderView(title: "Settings")
            Divider()
            SettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 360, minHeight: 420)
        .background(AppTheme.background)
        .glow(
            accent: AppTheme.accentViolet,
            intensity: .standard,
            active: bridge.isPinned
        )
    }
}

#Preview {
    SettingsWindowView()
        .environmentObject(PanelBridge())
        .environmentObject(SettingsStore())
}