import SwiftUI
import AppKit

struct TaskRowView: View {
    @EnvironmentObject private var taskStore: TaskStore

    let task: Task
    var isEditing: Bool
    var onBeginEdit: () -> Void
    var onEndEdit: () -> Void

    @State private var draft: String = ""
    @State private var stepDraft: String = ""
    @State private var editingFirstStep: Bool = false
    @State private var isSettingDeadline: Bool = false
    @State private var deadlineDraft: Date = Date()
    @FocusState private var editFocused: Bool
    @State private var isHovering: Bool = false

    /// Drives the completion animation: true while the row plays its ripple +
    /// teal background flash before being removed from the open list.
    @State private var completing = false

    var body: some View {
        Group {
            if isSettingDeadline {
                deadlineEditor
            } else if editingFirstStep {
                firstStepEditor
            } else if isEditing {
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
                HStack(spacing: 6) {
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

                    if let framing = task.framing {
                        framingBadge(for: framing)
                    }
                }

                if let firstStep = task.firstStep, !firstStep.isEmpty {
                    Text("1. \(firstStep)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.accentTeal)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let link = task.linkAttachments.first {
                    linkChip(for: link)
                }
                if let image = task.imageAttachments.first {
                    imageThumbnail(for: image)
                }
            }
            .opacity(completing ? 0.6 : 1)

            Spacer(minLength: 0)

            sizeMenu
            framingMenu

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

    /// FR-13: one small glyph reflecting the attached framing, text-free to
    /// avoid row clutter. ⚡ for quickWin, ⏭ for doFirstNextSession.
    private func framingBadge(for framing: TaskFraming) -> some View {
        Image(systemName: framing == .quickWin ? "bolt.fill" : "forward.end.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(framingColor(for: framing))
            .help(framingHelp(for: framing))
    }

    private func framingColor(for framing: TaskFraming) -> Color {
        switch framing {
        case .quickWin: return AppTheme.accentTeal
        case .doFirstNextSession: return AppTheme.accentViolet
        }
    }

    private func framingHelp(for framing: TaskFraming) -> String {
        switch framing {
        case .quickWin: return "Quick win — surfaces first in What now"
        case .doFirstNextSession: return "Do first next session"
        }
    }

    /// FR-13: the "..." context menu holding the three framing levers plus the
    /// FR-15 "add first step" action. All single-tap, no sub-forms.
    private var framingMenu: some View {
        Menu {
            Button("Set a deadline") {
                setDeadline()
            }
            Divider()
            Button(task.framing == .quickWin ? "Unmark quick win" : "Mark as quick win") {
                toggleFraming(.quickWin)
            }
            Button(task.framing == .quickWin ? "Do first next session →" : "Do first next session") {
                setFraming(.doFirstNextSession)
            }
            if task.framing == .doFirstNextSession {
                Button("Clear 'do first'") {
                    setFraming(nil)
                }
            }
            Divider()
            Button(firstStepExists ? "Edit first step…" : "Add first step…") {
                beginFirstStepEdit()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Task options")
    }

    private var firstStepExists: Bool {
        (task.firstStep ?? "").isEmpty == false
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

    private var sizeMenu: some View {
        Menu {
            ForEach(TaskSize.allCases, id: \.self) { size in
                Button {
                    setSize(size)
                } label: {
                    if task.size == size {
                        Label(size.label, systemImage: "checkmark")
                    } else {
                        Text(size.label)
                    }
                }
            }
            if task.size != nil {
                Divider()
                Button("Clear") { setSize(nil) }
            }
        } label: {
            Image(systemName: task.size?.symbol ?? "tag")
                .font(.system(size: 11))
                .foregroundStyle(
                    task.size != nil ? sizeColor : AppTheme.textSecondary
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Set task size")
    }

    private var sizeColor: Color {
        switch task.size {
        case .big: return AppTheme.accentCoral
        case .medium: return AppTheme.accentViolet
        case .small: return AppTheme.accentTeal
        case nil: return AppTheme.textSecondary
        }
    }

    private func setSize(_ size: TaskSize?) {
        var updated = task
        updated.size = size
        taskStore.update(updated)
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

    private var firstStepEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("First tiny step")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            TextField("e.g. Open the doc and write one sentence", text: $stepDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .onSubmit {
                    commitFirstStep()
                }
                .onExitCommand {
                    editingFirstStep = false
                    onEndEdit()
                }
            HStack {
                Button("Save") { commitFirstStep() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentTeal)
                Button("Clear") {
                    stepDraft = ""
                    commitFirstStep()
                }
                .buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .onAppear { editFocused = true }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deadlineEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Self-imposed deadline")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            DatePicker("",
                       selection: $deadlineDraft,
                       displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Set") { commitDeadline() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentTeal)
                if task.dueDate != nil {
                    Button("Clear") {
                        var updated = task
                        updated.dueDate = nil
                        taskStore.update(updated)
                        isSettingDeadline = false
                        onEndEdit()
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Framing (FR-13)

    /// quickWin is a toggle: setting it when already set clears it.
    private func toggleFraming(_ framing: TaskFraming) {
        var updated = task
        updated.framing = (task.framing == framing) ? nil : framing
        taskStore.update(updated)
    }

    private func setFraming(_ framing: TaskFraming?) {
        var updated = task
        updated.framing = framing
        taskStore.update(updated)
    }

    // MARK: - First step (FR-15)

    private func beginFirstStepEdit() {
        stepDraft = task.firstStep ?? ""
        editingFirstStep = true
        onBeginEdit()
    }

    private func commitFirstStep() {
        let trimmed = stepDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != (task.firstStep ?? "") {
            var updated = task
            updated.firstStep = trimmed.isEmpty ? nil : trimmed
            taskStore.update(updated)
        }
        editingFirstStep = false
        onEndEdit()
    }

    private func commitDeadline() {
        var updated = task
        updated.dueDate = deadlineDraft
        taskStore.update(updated)
        isSettingDeadline = false
        onEndEdit()
    }

    private func setDeadline() {
        deadlineDraft = task.dueDate ?? Date()
        isSettingDeadline = true
        onBeginEdit()
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