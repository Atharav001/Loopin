import SwiftUI

struct PanelRootView: View {
    var body: some View {
        Text("Loopin")
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .frame(minWidth: 280, minHeight: 400)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}