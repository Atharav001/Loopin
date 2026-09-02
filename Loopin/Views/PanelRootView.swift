import SwiftUI
import AppKit

struct PanelRootView: View {
    @EnvironmentObject private var bridge: PanelBridge

    var body: some View {
        VStack {
            HStack {
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
            .padding(12)

            Spacer()

            Text("Loopin")
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))

            Spacer()
        }
        .frame(minWidth: 280, minHeight: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .glow(
            accent: Color(hex: "#9B7BFF"),
            intensity: .standard,
            active: bridge.isPinned
        )
    }
}

#Preview {
    PanelRootView()
        .environmentObject(PanelBridge())
}