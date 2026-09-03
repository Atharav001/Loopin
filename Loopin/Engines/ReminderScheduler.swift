import Foundation
import UserNotifications

/// Two-stage reminder escalation (FR-7):
/// Stage 1 (t=0): `session.reminderPending = true` → status bar icon pulses.
/// Stage 2 (t=escalationDelay): if still unacknowledged, post a native
/// notification with Start Break/Start Focus, Snooze, and Dismiss actions.
/// There is intentionally no Stage 3.
final class ReminderScheduler: NSObject {
    static let categoryIdentifier = "LOOPIN_SESSION_END"

    private let session: TimerSession
    private let engine: TimerEngine
    private let settingsStore: SettingsStore
    private let taskStore: TaskStore

    private var stageTwoWork: DispatchWorkItem?
    private var snoozeWork: DispatchWorkItem?

    init(session: TimerSession, engine: TimerEngine, settingsStore: SettingsStore, taskStore: TaskStore) {
        self.session = session
        self.engine = engine
        self.settingsStore = settingsStore
        self.taskStore = taskStore
        super.init()
        engine.onSessionEnded = { [weak self] phase in
            self?.sessionEnded(phase)
        }
    }

    /// Called by UNUserNotificationCenterDelegate when a notification action fires.
    func handleAction(identifier: String) {
        switch identifier {
        case "START_BREAK":
            acknowledge()
            engine.startBreak()
        case "START_FOCUS":
            acknowledge()
            engine.startFocus()
        case "SNOOZE":
            snooze()
        case "DISMISS":
            acknowledge()
        default:
            acknowledge()
        }
    }

    /// Stops Stage 1 pulse and cancels any pending Stage 2 notification.
    func acknowledge() {
        session.reminderPending = false
        stageTwoWork?.cancel()
        stageTwoWork = nil
        snoozeWork?.cancel()
        snoozeWork = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["LOOPIN_REMINDER", "LOOPIN_SNOOZE"])
    }

    func sessionEnded(_ phase: TimerPhase) {
        // Stage 1: pulse now.
        session.reminderPending = true

        // Phase 15 (§6.1/6.4): Trigger full-screen attention overlay for session/timer end events
        let event: AttentionEventType
        switch phase {
        case .focus: event = .focusEnded
        case .breakShort, .breakLong: event = .breakEnded
        case .timer: event = .timerEnded
        case .idle: return
        }
        AttentionOverlayManager.shared.trigger(
            event: event,
            stimulationIntensity: settingsStore.settings.stimulationIntensity
        )

        // Stage 2: escalate after the configured delay if still unacknowledged.
        stageTwoWork?.cancel()
        let delay = settingsStore.settings.reminderEscalationDelaySeconds
        let item = DispatchWorkItem { [weak self] in
            self?.postNotification(phase: phase)
        }
        stageTwoWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func snooze() {
        // Keep pulsing, cancel the immediate Stage 2, re-arm after snooze length.
        stageTwoWork?.cancel()
        stageTwoWork = nil
        session.reminderPending = true

        let minutes = Double(max(1, settingsStore.settings.snoozeLengthMinutes))
        let item = DispatchWorkItem { [weak self] in
            self?.postSnoozeNotification()
        }
        snoozeWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + minutes * 60, execute: item)
    }

    private func postNotification(phase: TimerPhase) {
        guard session.reminderPending else { return }
        let center = UNUserNotificationCenter.current()

        let title: String
        switch phase {
        case .focus: title = "Focus session done"
        case .breakShort, .breakLong: title = "Break's over"
        case .timer: title = "Time's up"
        case .idle: return
        }

        let body: String
        if let id = session.linkedTaskId, let linked = taskStore.tasks.first(where: { $0.id == id }) {
            body = linked.title
        } else {
            body = "Ready when you are."
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = (settingsStore.settings.stimulationIntensity == .gentle) ? nil : .default
        content.categoryIdentifier = Self.categoryIdentifier

        let request = UNNotificationRequest(
            identifier: "LOOPIN_REMINDER",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    private func postSnoozeNotification() {
        guard session.reminderPending else { return }
        let content = UNMutableNotificationContent()
        content.title = "Still with you"
        content.body = "Ready when you are."
        content.sound = (settingsStore.settings.stimulationIntensity == .gentle) ? nil : .default
        content.categoryIdentifier = Self.categoryIdentifier

        let request = UNNotificationRequest(
            identifier: "LOOPIN_SNOOZE",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

extension ReminderScheduler {
    static func registerCategories() {
        let startBreak = UNNotificationAction(identifier: "START_BREAK", title: "Start Break")
        let startFocus = UNNotificationAction(identifier: "START_FOCUS", title: "Start Focus")
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Snooze", options: [.authenticationRequired])
        let dismiss = UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: [.destructive])

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [startBreak, startFocus, snooze, dismiss],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}