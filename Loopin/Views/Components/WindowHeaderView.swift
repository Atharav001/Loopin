import SwiftUI

/// Shared per-window chrome: title + pin toggle. Each window has its own
/// `WindowHeaderView` bound to its own `PanelBridge`, so pinning one window
/// never affects another (V1_IMPROVEMENTS §1.2).
struct WindowHeaderView: View {
    @EnvironmentObject private var bridge: PanelBridge
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            // Close button styled as a macOS dot
            Button {
                bridge.close()
            } label: {
                Circle()
                    .fill(Color(hex: "#FF5F56"))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(Color.black.opacity(0.6))
                            .opacity(0.8)
                    )
            }
            .buttonStyle(.plain)
            .help("Close window")

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Button {
                bridge.togglePin()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: bridge.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .semibold))
                    if bridge.isPinned {
                        Text("PINNED")
                            .font(.system(size: 9, weight: .bold))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(bridge.isPinned ? AppTheme.accentViolet.opacity(0.25) : Color.white.opacity(0.05))
                )
                .foregroundStyle(
                    bridge.isPinned
                        ? AppTheme.accentViolet
                        : AppTheme.textSecondary
                )
            }
            .buttonStyle(.plain)
            .help(bridge.isPinned ? "Pinned: always on top" : "Click to pin window on top")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.surface.opacity(0.7))
    }
}