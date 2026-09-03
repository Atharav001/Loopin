import WidgetKit
import SwiftUI

/// TimelineEntry representing task list state for the macOS Desktop Widget (§5.1).
struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [Task]
}

/// WidgetKit TimelineProvider fetching tasks live from JSONStore (§5.2).
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: Date(), tasks: [
            Task(title: "Design main layout", colorTag: .teal),
            Task(title: "Review PRD & specs", colorTag: .violet)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) {
        let tasks = loadTasks()
        completion(TaskEntry(date: Date(), tasks: tasks))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        let tasks = loadTasks()
        let entry = TaskEntry(date: Date(), tasks: tasks)
        // Refresh timeline every 15 mins or when triggered live by TaskStore save
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadTasks() -> [Task] {
        return JSONStore.load([Task].self, from: "tasks.json") ?? []
    }
}

/// Read-only macOS desktop widget view (§5.3) displaying open tasks live.
struct LoopinWidgetEntryView: View {
    var entry: Provider.Entry

    private var openTasks: [Task] {
        entry.tasks.filter { !$0.isComplete }.prefix(5).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Loopin Today")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.accentTeal)
                Spacer()
                Text("\(openTasks.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Divider()

            if openTasks.isEmpty {
                VStack {
                    Spacer()
                    Text("All clear for today!")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(openTasks) { task in
                        HStack(spacing: 6) {
                            if let tag = task.colorTag {
                                Circle()
                                    .fill(AppTheme.color(for: tag))
                                    .frame(width: 6, height: 6)
                            } else {
                                Image(systemName: "circle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Text(task.title)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(AppTheme.background)
    }
}

@main
struct LoopinWidget: Widget {
    let kind: String = "LoopinWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LoopinWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Loopin Tasks")
        .description("Displays your current open tasks live on your desktop.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
