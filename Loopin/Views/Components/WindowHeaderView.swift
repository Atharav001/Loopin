import SwiftUI

/// Shared per-window chrome: title + pin toggle. Each window has its own
/// `WindowHeaderView` bound to its own `PanelBridge`, so pinning one window
/// never affects another (V1_IMPROVEMENTS §1.2).
struct WindowHeaderView: View {
    @EnvironmentObject private var bridge: PanelBridge
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Button {
                bridge.togglePin()
            } label: {
                Image(systemName: bridge.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        bridge.isPinned
                            ? AppTheme.accentViolet
                            : AppTheme.textSecondary
                    )
            }
            .buttonStyle(.plain)
            .help(bridge.isPinned ? "Pinned: always on top" : "Not pinned")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}