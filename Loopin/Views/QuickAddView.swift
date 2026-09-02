import SwiftUI
import AppKit

struct QuickAddView: View {
    @EnvironmentObject private var taskStore: TaskStore
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color(hex: "#3DDC97"))

            TextField("Capture a thought…", text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit(submit)
                .font(.system(size: 13))
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // If the field holds an image (pasted), capture from the pasteboard.
        if trimmed.isEmpty, NSPasteboard.general.availableType(from: [.tiff, .png]) != nil {
            taskStore.add(from: CaptureClassifier.classify(pasteboard: NSPasteboard.general))
        } else {
            guard !trimmed.isEmpty else { return }
            taskStore.add(from: CaptureClassifier.classifyText(trimmed))
        }
        text = ""
        isFocused = true
    }
}

#Preview {
    QuickAddView()
        .environmentObject(TaskStore())
        .padding()
}