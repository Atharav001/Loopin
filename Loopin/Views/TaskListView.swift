import SwiftUI
import UniformTypeIdentifiers

struct TaskListView: View {
    @EnvironmentObject private var taskStore: TaskStore
    @State private var editingTaskID: UUID?
    @State private var isDropTarget: Bool = false

    private var openTasks: [Task] {
        taskStore.tasks
            .filter { !$0.isComplete }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        Group {
            if openTasks.isEmpty {
                emptyState
            } else {
                taskScroll
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

    private var taskScroll: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(openTasks) { task in
                    TaskRowView(
                        task: task,
                        isEditing: editingTaskID == task.id,
                        onBeginEdit: { editingTaskID = task.id },
                        onEndEdit: { editingTaskID = nil }
                    )
                }
            }
            .padding(10)
        }
    }
}

#Preview {
    TaskListView()
        .environmentObject(TaskStore())
}