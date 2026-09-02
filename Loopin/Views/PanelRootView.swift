import SwiftUI
import AppKit

struct PanelRootView: View {
    @EnvironmentObject private var bridge: PanelBridge

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            QuickAddView()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            Divider()
            TaskListView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 320, minHeight: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .glow(
            accent: Color(hex: "#9B7BFF"),
            intensity: .standard,
            active: bridge.isPinned
        )
    }

    private var header: some View {
        HStack {
            Text("Loopin")
                .font(.headline)
                .foregroundStyle(Color(nsColor: .labelColor))
            Spacer()
            Button {
                bridge.togglePin()
            } label: {
                Image(systemName: bridge.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        bridge.isPinned
                            ? Color(hex: "#9B7BFF")
                            : Color(nsColor: .secondaryLabelColor)
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
    PanelRootView()
        .environmentObject(PanelBridge())
        .environmentObject(TaskStore())
}