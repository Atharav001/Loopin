import AppKit
import Combine
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var panelController: PanelController?
    private var appState: AppState?
    private var reminderScheduler: ReminderScheduler?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settingsStore = SettingsStore()
        let taskStore = TaskStore()
        let timerSession = TimerSession()
        let panelBridge = PanelBridge()

        let panelController = PanelController(
            settingsStore: settingsStore,
            panelBridge: panelBridge
        )
        let appState = AppState(
            settingsStore: settingsStore,
            taskStore: taskStore,
            panelBridge: panelBridge,
            timerSession: timerSession
        )
        self.appState = appState

        panelController.installRoot(appState: appState)
        self.panelController = panelController

        let statusBarController = StatusBarController(
            panelController: panelController,
            timerSession: timerSession
        )
        self.statusBarController = statusBarController

        timerSession.$phase
            .sink { _ in statusBarController.refreshIcon() }
            .store(in: &cancellables)
        timerSession.$reminderPending
            .sink { _ in statusBarController.refreshIcon() }
            .store(in: &cancellables)

        // Reminder escalation (FR-7).
        let scheduler = ReminderScheduler(
            session: timerSession,
            engine: appState.timerEngine,
            settingsStore: settingsStore,
            taskStore: taskStore
        )
        self.reminderScheduler = scheduler

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        ReminderScheduler.registerCategories()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Opening the panel acknowledges any pending reminder.
        NotificationCenter.default.publisher(for: .panelDidOpen)
            .sink { [weak self] _ in self?.reminderScheduler?.acknowledge() }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.saveFrame()
        appState?.taskStore.saveNow()
        appState?.settingsStore.saveNow()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        reminderScheduler?.handleAction(identifier: response.actionIdentifier)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}