import SwiftUI
import AppKit

struct PanelRootView: View {
    @EnvironmentObject private var bridge: PanelBridge

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            TimerView()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Divider()
            QuickAddView()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            Divider()
            TaskListView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 320, minHeight: 400)
        .background(AppTheme.background)
        .glow(
            accent: AppTheme.accentViolet,
            intensity: .standard,
            active: bridge.isPinned
        )
    }

    private var header: some View {
        HStack {
            Text("Loopin")
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

#Preview {
    PanelPreview()
}

private struct PanelPreview: View {
    @State private var session = TimerSession()
    var body: some View {
        PanelRootView()
            .environmentObject(PanelBridge())
            .environmentObject(TaskStore())
            .environmentObject(SettingsStore())
            .environmentObject(TimerEngine(session: session))
            .environmentObject(session)
    }
}