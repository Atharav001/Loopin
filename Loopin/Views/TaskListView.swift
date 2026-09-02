import SwiftUI
import UniformTypeIdentifiers

struct TaskListView: View {
    @EnvironmentObject private var taskStore: TaskStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var editingTaskID: UUID?
    @State private var isDropTarget: Bool = false
    @State private var showingLater = false

    private var openTasks: [Task] {
        taskStore.tasks
            .filter { !$0.isComplete }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// FR-11: when the daily cap is enabled, split open tasks into a primary
    /// list (within the 1 big + 3 medium + 5 small budget) and a "later" set.
    private var capPartition: (primary: [Task], later: [Task]) {
        guard settingsStore.settings.dailyCapEnabled else {
            return (openTasks, [])
        }
        var counts: [TaskSize: Int] = [:]
        var primary: [Task] = []
        var later: [Task] = []
        for task in openTasks {
            // Unsized tasks count toward the smallest bucket so enabling the cap
            // reads as "top N" instead of hiding everything unlabeled.
            let size = task.size ?? .small
            let limit = capLimit(for: size)
            let used = counts[size, default: 0]
            if used < limit {
                counts[size, default: 0] += 1
                primary.append(task)
            } else {
                later.append(task)
            }
        }
        return (primary, later)
    }

    private func capLimit(for size: TaskSize) -> Int {
        switch size {
        case .big: return 1
        case .medium: return 3
        case .small: return 5
        }
    }

    var body: some View {
        let partition = capPartition
        Group {
            if openTasks.isEmpty {
                emptyState
            } else {
                taskScroll(primary: partition.primary, later: partition.later)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isDropTarget ? AppTheme.accentTeal : Color.clear,
                    lineWidth: 1.5
                )
        )
        .padding(4)
        .onDrop(of: [.image, .url], isTargeted: $isDropTarget) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var created = false
        for provider in providers {
            let semaphore = DispatchSemaphore(value: 0)
            var classified: ClassifiedContent?

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, _ in
                    if let data {
                        let fileName = "\(UUID().uuidString).png"
                        if JSONStore.writeImage(data, named: fileName) {
                            classified = ClassifiedContent(
                                titleText: "Image",
                                url: nil,
                                imageFileName: fileName,
                                dueDate: nil,
                                rawPasteboardText: ""
                            )
                            created = true
                        }
                    }
                    semaphore.signal()
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        classified = ClassifiedContent(
                            titleText: url.absoluteString,
                            url: url,
                            imageFileName: nil,
                            dueDate: nil,
                            rawPasteboardText: url.absoluteString
                        )
                        created = true
                    }
                    semaphore.signal()
                }
            } else {
                semaphore.signal()
            }

            semaphore.wait()
            if let classified {
                taskStore.add(from: classified)
            }
        }
        return created
    }

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

    private func taskScroll(primary: [Task], later: [Task]) -> some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(primary) { task in
                    row(for: task)
                }

                if !later.isEmpty {
                    Divider().padding(.vertical, 4)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingLater.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: showingLater ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10))
                            Text("\(later.count) later")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)

                    if showingLater {
                        ForEach(later) { task in
                            row(for: task)
                        }
                    }
                }
            }
            .padding(10)
        }
    }

    private func row(for task: Task) -> some View {
        TaskRowView(
            task: task,
            isEditing: editingTaskID == task.id,
            onBeginEdit: { editingTaskID = task.id },
            onEndEdit: { editingTaskID = nil }
        )
    }
}

#Preview {
    TaskListView()
        .environmentObject(TaskStore())
        .environmentObject(SettingsStore())
}