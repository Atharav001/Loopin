import Foundation

struct TimerPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var focusMinutes: Int
    var breakMinutes: Int
    var longBreakMinutes: Int
    var cyclesBeforeLongBreak: Int

    init(
        id: UUID = UUID(),
        name: String,
        focusMinutes: Int,
        breakMinutes: Int,
        longBreakMinutes: Int,
        cyclesBeforeLongBreak: Int = 4
    ) {
        self.id = id
        self.name = name
        self.focusMinutes = focusMinutes
        self.breakMinutes = breakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.cyclesBeforeLongBreak = cyclesBeforeLongBreak
    }

    static let defaults: [TimerPreset] = [
        TimerPreset(name: "Low energy", focusMinutes: 10, breakMinutes: 5, longBreakMinutes: 15),
        TimerPreset(name: "Normal", focusMinutes: 20, breakMinutes: 5, longBreakMinutes: 15),
        TimerPreset(name: "Deep work", focusMinutes: 45, breakMinutes: 10, longBreakMinutes: 20),
    ]
}