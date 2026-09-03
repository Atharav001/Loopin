import Foundation
import Combine

final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet { scheduleSave() }
    }

    private let settingsFile = "settings.json"
    private var saveWorkItem: DispatchWorkItem?
    private let saveQueue = DispatchQueue(label: "com.loopin.settingsave")

    init() {
        let saved = JSONStore.load(AppSettings.self, from: settingsFile)
        settings = saved ?? .default
        migrateWindowFrames()
        scheduleSave()
    }

    /// One-time migration (V1_IMPROVEMENTS §7): the singular `panelFrame` is
    /// replaced by the per-window `windowFrames` dictionary. If a legacy frame
    /// exists (from the To-Do list effectively being "the app" before the
    /// multi-window change), seed `windowFrames["todo"]` from it.
    private func migrateWindowFrames() {
        guard let legacy = settings.panelFrame else { return }
        guard let current = settings.windowFrames["todo"] else {
            settings.windowFrames["todo"] = legacy
            scheduleSave()
            return
        }
        _ = current
    }

    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        JSONStore.save(settings, to: settingsFile)
    }

    /// Debounced save so rapid edits (typing a preset name, stepping a value)
    /// don't write the whole file on every keystroke. The frame is intentionally
    /// excluded from these debounced writes; PanelController saves it directly.
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            JSONStore.save(self.settings, to: self.settingsFile)
        }
        saveWorkItem = item
        saveQueue.asyncAfter(deadline: .now() + 0.4, execute: item)
    }
}