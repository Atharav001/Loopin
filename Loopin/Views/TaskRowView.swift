import SwiftUI
import AppKit

struct TaskRowView: View {
    @EnvironmentObject private var taskStore: TaskStore

    let task: Task
    var isEditing: Bool
    var onBeginEdit: () -> Void
    var onEndEdit: () -> Void

    @State private var draft: String = ""
    @FocusState private var editFocused: Bool
    @State private var isHovering: Bool = false

    /// Drives the completion animation: true while the row plays its ripple +
    /// teal background flash before being removed from the open list.
    @State private var completing = false

    var body: some View {
        Group {
            if isEditing {
                editingRow
            } else {
                displayRow
            }
        }
        .transition(.opacity)
    }

    private var displayRow: some View {
        HStack(spacing: 8) {
            Button {
                complete()
            } label: {
                Image(systemName: completing ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(completing ? AppTheme.accentTeal : AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Mark done")
            .disabled(completing)
            .ripple(trigger: completing, color: AppTheme.accentTeal)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) {
                        draft = task.title
                        onBeginEdit()
                        editFocused = true
                    }
                    .contentShape(Rectangle())

                if let link = task.linkAttachments.first {
                    linkChip(for: link)
                }
                if let image = task.imageAttachments.first {
                    imageThumbnail(for: image)
                }
            }
            .opacity(completing ? 0.6 : 1)

            Spacer(minLength: 0)

            if let dueDate = task.dueDate {
                Text(dueDate, style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Button {
                taskStore.delete(id: task.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .disabled(!isHovering)
            .help("Delete")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowBackground)
        )
        .onHover { isHovering = $0 }
    }

    private var rowBackground: Color {
        if completing {
            return AppTheme.accentTeal.opacity(0.18)
        }
        if isHovering {
            return AppTheme.surface.opacity(1)
        }
        return AppTheme.surface
    }

    private func linkChip(for link: LinkAttachment) -> some View {
        HStack(spacing: 4) {
            if let favicon = link.faviconData,
               let nsImage = NSImage(data: favicon) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: "link")
                    .font(.system(size: 10))
            }
            Text(link.fetchedTitle ?? link.url.host ?? link.url.lastPathComponent)
                .font(.system(size: 11))
                .lineLimit(1)
            Link("Open", destination: link.url)
                .font(.system(size: 10))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(AppTheme.surface)
        )
    }

    private func imageThumbnail(for image: ImageAttachment) -> some View {
        Group {
            if let data = JSONStore.readImage(named: image.imageFileName),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var editingRow: some View {
        TextField("Task title", text: $draft)
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 13))
            .focused($editFocused)
            .onSubmit {
                commitEdit()
            }
            .onAppear { editFocused = true }
            .onChange(of: editFocused) { _, focused in
                guard isEditing, !focused else { return }
                commitEdit()
            }
            .onExitCommand {
                onEndEdit()
            }
            .padding(.vertical, 2)
    }

    private func complete() {
        guard !completing else { return }
        completing = true

        // Run the completion animation (ripple + teal flash) for ~300ms, then
        // mark the task complete so it drops off the open list.
        Swift.Task { @MainActor in
            try? await Swift.Task.sleep(nanoseconds: 360_000_000)
            var updated = task
            updated.isComplete = true
            taskStore.update(updated)
        }
    }

    private func commitEdit() {
        guard isEditing else { return }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != task.title {
            var updated = task
            updated.title = trimmed
            taskStore.update(updated)
        }
        onEndEdit()
    }
}

#Preview {
    TaskRowView(
        task: Task(title: "File the taxes"),
        isEditing: false,
        onBeginEdit: {},
        onEndEdit: {}
    )
    .environmentObject(TaskStore())
    .padding()
}