import SwiftUI
import AppKit

struct QuickAddView: View {
    @EnvironmentObject private var taskStore: TaskStore
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.accentTeal)

            TextField("Add a new task or drop a file…", text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit(submit)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isFocused ? AppTheme.accentTeal : AppTheme.borderSubtle, lineWidth: isFocused ? 1.5 : 1)
                )
                .shadow(color: isFocused ? AppTheme.accentTeal.opacity(0.3) : Color.clear, radius: 8)
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