import SwiftUI
import UniformTypeIdentifiers

/// Memorigi-style sectioned To-Do list (V1_IMPROVEMENTS §4):
/// Today / Later / collapsible Completed, along with the important-flag filter
/// (§4.2.1), delete-with-undo toast (§4.4.2) and clear-completed (§4.4.3).
struct TaskListView: View {
    @EnvironmentObject private var taskStore: TaskStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var editingTaskID: UUID?
    @State private var isDropTarget: Bool = false
    @State private var showingLater = false
    @State private var showingCompleted = false
    /// Filter to show only important open/today tasks (§4.2.1).
    @State private var importantOnly = false
    /// Delete-undo (§4.4.2): the task removed and awaiting an Undo action.
    @State private var pendingUndoTask: Task?
    @State private var undoWork: DispatchWorkItem?
    /// Clear-completed inline confirmation (§4.4.3).
    @State private var confirmingClear = false

    // MARK: - Sectioning

    private var openTasks: [Task] {
        taskStore.tasks
            .filter { !$0.isComplete }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var completedTasks: [Task] {
        taskStore.tasks
            .filter { $0.isComplete }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Today: open tasks with no future due date (no date or due today).
    private var todayTasks: [Task] {
        importantOnly
            ? openTasks.filter { $0.isImportant && !isFutureDue($0) }
            : openTasks.filter { !isFutureDue($0) }
    }

    /// Later: open tasks due in the future.
    private var laterTasks: [Task] {
        importantOnly ? [] : openTasks.filter { isFutureDue($0) }
    }

    private func isFutureDue(_ task: Task) -> Bool {
        guard let due = task.dueDate else { return false }
        return due > Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            Group {
                if taskStore.tasks.isEmpty {
                    emptyState
                } else {
                    taskScroll
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: taskStore.tasks)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDropTarget ? AppTheme.accentTeal : Color.clear,
                    lineWidth: 2
                )
                .shadow(color: isDropTarget ? AppTheme.accentTeal.opacity(0.5) : Color.clear, radius: 8)
        )
        .padding(4)
        .onDrop(of: [.image, .url, .fileURL], isTargeted: $isDropTarget) { providers in
            handleNewTaskDrop(providers)
        }
        .overlay(alignment: .bottom) { undoBar }
    }

    // MARK: - Filter bar (§4.2.1)

    private var filterBar: some View {
        HStack {
            Button {
                importantOnly.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: importantOnly ? "star.fill" : "star")
                        .font(.system(size: 11))
                    Text("Important")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(importantOnly ? Color.black : AppTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(importantOnly ? AppTheme.accentViolet : AppTheme.surface)
                )
            }
            .buttonStyle(.plain)

            Spacer()
            if !completedTasks.isEmpty {
                Button {
                    showingCompleted.toggle()
                } label: {
                    Label("Completed (\(completedTasks.count))", systemImage: "checkmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - New-task drop (§4.3.1 blank drop target)

    private func handleNewTaskDrop(_ providers: [NSItemProvider]) -> Bool {
        var created = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, _ in
                    if let data {
                        let fileName = "\(UUID().uuidString).png"
                        if JSONStore.writeImage(data, named: fileName) {
                            DispatchQueue.main.async {
                                taskStore.add(from: ClassifiedContent(
                                    titleText: "Image",
                                    url: nil,
                                    imageFileName: fileName,
                                    dueDate: nil,
                                    rawPasteboardText: ""
                                ))
                            }
                        }
                    }
                }
                created = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        DispatchQueue.main.async {
                            taskStore.add(from: ClassifiedContent(
                                titleText: url.absoluteString,
                                url: url,
                                imageFileName: nil,
                                dueDate: nil,
                                rawPasteboardText: url.absoluteString
                            ))
                        }
                    }
                }
                created = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                loadFileDrop(provider) { newTask in
                    DispatchQueue.main.async {
                        taskStore.add(newTask)
                    }
                }
                created = true
            }
        }
        return created
    }

    /// Loads a generic file drop and builds a new task (§4.3.1 blank target:
    /// auto-fill title from the filename without extension).
    private func loadFileDrop(_ provider: NSItemProvider, completion: @escaping (Task) -> Void) {
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, let data = try? Data(contentsOf: url) else { return }
            let fileName = url.lastPathComponent
            let storedName = "\(UUID().uuidString).\(url.pathExtension)"
            guard JSONStore.writeAttachment(data, named: storedName) else { return }
            let title = (fileName as NSString).deletingPathExtension
            let attachment = FileAttachment.make(fileName: fileName)
            completion(Task(title: title, fileAttachments: [attachment]))
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 26))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Nothing open right now")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Drop a thought in above — no forms needed.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Sections

    private var taskScroll: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                sectionHeader(title: "Today", count: todayTasks.count)
                ForEach(todayTasks) { task in
                    row(for: task)
                }

                if !laterTasks.isEmpty {
                    sectionHeader(
                        title: "Later",
                        count: laterTasks.count,
                        collapsible: false
                    )
                    ForEach(laterTasks) { task in
                        row(for: task)
                    }
                }

                if !completedTasks.isEmpty {
                    sectionHeader(
                        title: "Completed",
                        count: completedTasks.count,
                        collapsible: true,
                        isExpanded: showingCompleted
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingCompleted.toggle()
                        }
                    }

                    if showingCompleted {
                        ForEach(completedTasks) { task in
                            row(for: task)
                        }
                        clearCompletedRow
                    }
                }
            }
            .padding(10)
        }
    }

    private func sectionHeader(
        title: String,
        count: Int,
        collapsible: Bool = true,
        isExpanded: Bool = true,
        toggle: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 6) {
            if collapsible, let toggle {
                Button(action: toggle) {
                    HStack(spacing: 5) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("(\(count))")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    if count > 0 {
                        Text("(\(count))")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    private var clearCompletedRow: some View {
        HStack {
            if confirmingClear {
                Text("Clear \(completedTasks.count) completed task\(completedTasks.count == 1 ? "" : "s")?")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textPrimary)
                Button("Clear") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        taskStore.clearCompleted()
                        confirmingClear = false
                        showingCompleted = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentCoral)
                .foregroundStyle(Color.black)
                Button("Cancel") { confirmingClear = false }
                    .buttonStyle(.bordered)
            } else {
                Button {
                    confirmingClear = true
                } label: {
                    Label("Clear completed", systemImage: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.accentCoral)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 6)
    }

    // MARK: - Rows

    private func row(for task: Task) -> some View {
        TaskRowView(
            task: task,
            isEditing: editingTaskID == task.id,
            onBeginEdit: { editingTaskID = task.id },
            onEndEdit: { editingTaskID = nil },
            onDelete: { deletedTask in removeWithUndo(deletedTask) }
        )
    }

    private func removeWithUndo(_ task: Task) {
        taskStore.delete(id: task.id)
        pendingUndoTask = task
        undoWork?.cancel()
        let targetID = task.id
        let item = DispatchWorkItem {
            clearUndoIfMatch(targetID)
        }
        undoWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: item)
    }

    /// Auto-dismisses the undo toast after its window elapses, only if no newer
    /// deletion replaced it.
    private func clearUndoIfMatch(_ taskID: UUID) {
        guard pendingUndoTask?.id == taskID else { return }
        pendingUndoTask = nil
        undoWork = nil
    }

    private func performUndo() {
        guard let task = pendingUndoTask else { return }
        taskStore.restore(task)
        pendingUndoTask = nil
        undoWork?.cancel()
        undoWork = nil
    }

    private var undoBar: some View {
        Group {
            if let task = pendingUndoTask {
                HStack(spacing: 8) {
                    Text("Deleted \"\(task.title)\"")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Button("Undo") { performUndo() }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentTeal)
                        .foregroundStyle(Color.black)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.surface)
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onExitCommand { performUndo() }
            }
        }
    }
}

/// Tiny gate helper so the undo toast self-clears after its window elapses.
#Preview {
    TaskListView()
        .environmentObject(TaskStore())
        .environmentObject(SettingsStore())
}