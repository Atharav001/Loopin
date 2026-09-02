import Foundation

/// Deterministic single-pick selection rule for "What now" (FR-14, DESIGN §11).
/// Three transparent tiers; never an opaque ranker.
enum WhatNowSelector {

    /// Returns the single task to do next, using the priority ladder:
    /// 1. A framed "quick win" due today or overdue (or with no due date).
    /// 2. The smallest-sized task due today (falls through if sizes never tagged).
    /// 3. The oldest uncompleted task by `createdAt` (always answers if non-empty).
    ///
    /// `excluding` is used by the "different one" re-roll so the same task never
    /// repeats back-to-back.
    static func whatNow(tasks: [Task], excluding: UUID? = nil) -> Task? {
        let calendar = Calendar.current
        let candidates = tasks.filter { !$0.isComplete && $0.id != excluding }
        guard !candidates.isEmpty else { return nil }

        // Priority 1: quick-win framing due today or overdue (or no due date).
        if let quickWin = candidates.first(where: {
            $0.framing == .quickWin && ($0.dueDate == nil || $0.dueDate! <= Date())
        }) {
            return quickWin
        }

        // Priority 2: smallest-sized task due today.
        if let smallToday = candidates
            .filter({ $0.size == .small && $0.dueDate != nil && calendar.isDateInToday($0.dueDate!) })
            .first {
            return smallToday
        }

        // Priority 3: oldest uncompleted by createdAt.
        return candidates.min { $0.createdAt < $1.createdAt }
    }
}