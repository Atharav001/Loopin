import Foundation
import CoreGraphics

enum StimulationIntensity: String, Codable, Equatable, CaseIterable {
    case gentle
    case standard
    case high
}

/// Focus Interval Alarm settings (V1_IMPROVEMENTS §3/§7): a repeating
/// metronome-style interval alarm independent of the Pomodoro timer.
struct FocusIntervalAlarmSettings: Codable, Equatable {
    /// One of {2,3,5,10,15,20,25}, validated at the UI layer.
    var intervalMinutes: Int = 10
    var isRunning: Bool = false
}

struct AppSettings: Codable, Equatable {
    var pinnedByDefault: Bool
    var panelFrame: CGRect?
    /// Per-window persisted frames, keyed by `WindowKind.rawValue`
    /// ("todo" / "timer" / "alarms" / "settings"). Replaces singular panelFrame.
    var windowFrames: [String: CGRect]
    /// Per-window pin state, same keys as windowFrames.
    var windowPinned: [String: Bool]
    var reminderEscalationDelaySeconds: TimeInterval
    var snoozeLengthMinutes: Int
    var stimulationIntensity: StimulationIntensity
    var dailyCapEnabled: Bool
    var presets: [TimerPreset]
    var focusIntervalAlarm: FocusIntervalAlarmSettings

    init(
        pinnedByDefault: Bool = false,
        panelFrame: CGRect? = nil,
        windowFrames: [String: CGRect] = [:],
        windowPinned: [String: Bool] = [:],
        reminderEscalationDelaySeconds: TimeInterval = 30,
        snoozeLengthMinutes: Int = 5,
        stimulationIntensity: StimulationIntensity = .standard,
        dailyCapEnabled: Bool = false,
        presets: [TimerPreset] = TimerPreset.defaults,
        focusIntervalAlarm: FocusIntervalAlarmSettings = FocusIntervalAlarmSettings()
    ) {
        self.pinnedByDefault = pinnedByDefault
        self.panelFrame = panelFrame
        self.windowFrames = windowFrames
        self.windowPinned = windowPinned
        self.reminderEscalationDelaySeconds = reminderEscalationDelaySeconds
        self.snoozeLengthMinutes = snoozeLengthMinutes
        self.stimulationIntensity = stimulationIntensity
        self.dailyCapEnabled = dailyCapEnabled
        self.presets = presets
        self.focusIntervalAlarm = focusIntervalAlarm
    }

    static let `default` = AppSettings()
}

// MARK: - Custom Codable for backward compatibility
//
// The new non-optional fields (windowFrames, windowPinned, focusIntervalAlarm)
// don't exist in settings.json files written by earlier Phases. A synthesized
// Codable init would THROW on their absence, silently discarding the user's
// existing settings. This decode-if-present impl preserves legacy files and
// seeds defaults for the new fields.

extension AppSettings {
    private enum CodingKeys: String, CodingKey {
        case pinnedByDefault, panelFrame, windowFrames, windowPinned
        case reminderEscalationDelaySeconds, snoozeLengthMinutes
        case stimulationIntensity, dailyCapEnabled, presets, focusIntervalAlarm
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pinnedByDefault = try c.decodeIfPresent(Bool.self, forKey: .pinnedByDefault) ?? false
        panelFrame = try c.decodeIfPresent(CGRect.self, forKey: .panelFrame)
        windowFrames = try c.decodeIfPresent([String: CGRect].self, forKey: .windowFrames) ?? [:]
        windowPinned = try c.decodeIfPresent([String: Bool].self, forKey: .windowPinned) ?? [:]
        reminderEscalationDelaySeconds =
            try c.decodeIfPresent(TimeInterval.self, forKey: .reminderEscalationDelaySeconds) ?? 30
        snoozeLengthMinutes = try c.decodeIfPresent(Int.self, forKey: .snoozeLengthMinutes) ?? 5
        stimulationIntensity =
            try c.decodeIfPresent(StimulationIntensity.self, forKey: .stimulationIntensity) ?? .standard
        dailyCapEnabled = try c.decodeIfPresent(Bool.self, forKey: .dailyCapEnabled) ?? false
        presets = try c.decodeIfPresent([TimerPreset].self, forKey: .presets) ?? TimerPreset.defaults
        focusIntervalAlarm =
            try c.decodeIfPresent(FocusIntervalAlarmSettings.self, forKey: .focusIntervalAlarm)
            ?? FocusIntervalAlarmSettings()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pinnedByDefault, forKey: .pinnedByDefault)
        try c.encodeIfPresent(panelFrame, forKey: .panelFrame)
        try c.encode(windowFrames, forKey: .windowFrames)
        try c.encode(windowPinned, forKey: .windowPinned)
        try c.encode(reminderEscalationDelaySeconds, forKey: .reminderEscalationDelaySeconds)
        try c.encode(snoozeLengthMinutes, forKey: .snoozeLengthMinutes)
        try c.encode(stimulationIntensity, forKey: .stimulationIntensity)
        try c.encode(dailyCapEnabled, forKey: .dailyCapEnabled)
        try c.encode(presets, forKey: .presets)
        try c.encode(focusIntervalAlarm, forKey: .focusIntervalAlarm)
    }
}