import Foundation
import CoreGraphics

enum StimulationIntensity: String, Codable, Equatable, CaseIterable {
    case gentle
    case standard
    case high
}

struct AppSettings: Codable, Equatable {
    var pinnedByDefault: Bool
    var panelFrame: CGRect?
    var reminderEscalationDelaySeconds: TimeInterval
    var snoozeLengthMinutes: Int
    var stimulationIntensity: StimulationIntensity
    var dailyCapEnabled: Bool
    var presets: [TimerPreset]

    init(
        pinnedByDefault: Bool = false,
        panelFrame: CGRect? = nil,
        reminderEscalationDelaySeconds: TimeInterval = 30,
        snoozeLengthMinutes: Int = 5,
        stimulationIntensity: StimulationIntensity = .standard,
        dailyCapEnabled: Bool = false,
        presets: [TimerPreset] = TimerPreset.defaults
    ) {
        self.pinnedByDefault = pinnedByDefault
        self.panelFrame = panelFrame
        self.reminderEscalationDelaySeconds = reminderEscalationDelaySeconds
        self.snoozeLengthMinutes = snoozeLengthMinutes
        self.stimulationIntensity = stimulationIntensity
        self.dailyCapEnabled = dailyCapEnabled
        self.presets = presets
    }

    static let `default` = AppSettings()
}