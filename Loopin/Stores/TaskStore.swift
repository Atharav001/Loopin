import Foundation
import Combine
import WidgetKit

final class TaskStore: ObservableObject {
    @Published var tasks: [Task] = []

    private let tasksFile = "tasks.json"
    private var saveWorkItem: DispatchWorkItem?
    private let saveQueue = DispatchQueue(label: "com.loopin.tasksave")

    init() {
        load()
    }

    func load() {
        tasks = JSONStore.load([Task].self, from: tasksFile) ?? []
    }

    func add(_ task: Task) {
        var updated = task
        updated.sortOrder = tasks.count
        tasks.append(updated)
        scheduleSave()
    }

    /// Builds a Task from captured content. If a URL link is present, metadata
    /// (page title, favicon) is fetched asynchronously and attached after the
    /// task already exists — never blocks capture.
    func add(from classified: ClassifiedContent) {
        var task = Task(
            title: classified.titleText,
            dueDate: classified.dueDate
        )
        if let fileName = classified.imageFileName {
            task.imageAttachments = [ImageAttachment(imageFileName: fileName)]
        }
        if let url = classified.url {
            task.linkAttachments = [LinkAttachment(url: url)]
        }
        add(task)

        guard let url = classified.url else { return }
        let taskID = task.id
        Swift.Task { [weak self] () async -> Void in
            let metadata = await LinkMetadataFetcher.fetch(for: url)
            guard let self else { return }
            await self.apply(metadata: metadata, to: taskID)
        }
    }

    @MainActor
    private func apply(metadata: (title: String?, favicon: Data?), to id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }),
              var current = tasks[index].linkAttachments.first else { return }
        current.fetchedTitle = metadata.title ?? current.fetchedTitle
        current.faviconData = metadata.favicon ?? current.faviconData
        tasks[index].linkAttachments[0] = current
        if let title = metadata.title, !title.isEmpty {
            let existing = tasks[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
            if existing.isEmpty || existing == current.url.absoluteString || existing == current.url.host {
                tasks[index].title = title
            }
        }
        scheduleSave()
    }

    func update(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        scheduleSave()
    }

    func delete(id: UUID) {
        tasks.removeAll { $0.id == id }
        scheduleSave()
    }

    /// Restores a previously removed task (delete-undo, §4.4.2).
    func restore(_ task: Task) {
        guard !tasks.contains(where: { $0.id == task.id }) else { return }
        tasks.append(task)
        scheduleSave()
    }

    /// Permanently removes all completed tasks (§4.4.3).
    func clearCompleted() {
        tasks.removeAll { $0.isComplete }
        scheduleSave()
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        tasks.move(fromOffsets: fromOffsets, toOffset: toOffset)
        scheduleSave()
    }

    func saveNow() {
        saveWorkItem?.cancel()
        JSONStore.save(tasks, to: tasksFile)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func scheduleSave() {
        WidgetCenter.shared.reloadAllTimelines()
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            JSONStore.save(self.tasks, to: self.tasksFile)
            WidgetCenter.shared.reloadAllTimelines()
        }
        saveWorkItem = item
        saveQueue.asyncAfter(deadline: .now() + 0.3, execute: item)
    }
}