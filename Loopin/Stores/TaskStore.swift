import Foundation
import Combine

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

    func update(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        scheduleSave()
    }

    func delete(id: UUID) {
        tasks.removeAll { $0.id == id }
        scheduleSave()
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        tasks.move(fromOffsets: fromOffsets, toOffset: toOffset)
        scheduleSave()
    }

    func saveNow() {
        saveWorkItem?.cancel()
        JSONStore.save(tasks, to: tasksFile)
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            JSONStore.save(self.tasks, to: self.tasksFile)
        }
        saveWorkItem = item
        saveQueue.asyncAfter(deadline: .now() + 0.5, execute: item)
    }
}