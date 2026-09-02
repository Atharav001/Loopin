import SwiftUI

/// FR-14: "What now" single-pick mode. Shows exactly ONE suggested task
/// (deterministic rule from DESIGN §11), never a list. A single "different one"
/// affordance re-rolls without repeating the immediately-previous suggestion.
struct WhatNowView: View {
    @EnvironmentObject private var taskStore: TaskStore

    /// The task currently shown, kept in state so re-roll can exclude it.
    @State private var current: Task?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What now?")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if let task = current {
                suggestionCard(for: task)
            } else {
                Text("Nothing open — nice.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.surface)
        )
        .onAppear { reReroll(forceFresh: true) }
        .onChange(of: taskStore.tasks.count) { _,_ in
            // If the suggested task disappeared (completed/deleted), assume fresh.
            if let c = current, !taskStore.tasks.contains(where: { $0.id == c.id }) {
                reReroll(forceFresh: true)
            }
        }
    }

    @ViewBuilder
    private func suggestionCard(for task: Task) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                if let step = task.firstStep, !step.isEmpty {
                    Text(step)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accentTeal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(task.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack(spacing: 10) {
                Button {
                    reReroll()
                } label: {
                    Label("Show me a different one", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                }
                .buttonStyle(.link)
            }
        }
    }

    private func reReroll(forceFresh: Bool = false) {
        let excluding = forceFresh ? nil : current?.id
        current = WhatNowSelector.whatNow(tasks: taskStore.tasks, excluding: excluding)
    }
}

#Preview {
    WhatNowView()
        .environmentObject(TaskStore())
        .padding()
        .background(AppTheme.background)
}