import Foundation
import Combine

final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings

    private let settingsFile = "settings.json"

    init() {
        let saved = JSONStore.load(AppSettings.self, from: settingsFile)
        settings = saved ?? .default
    }

    func saveNow() {
        JSONStore.save(settings, to: settingsFile)
    }
}