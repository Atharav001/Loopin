import Foundation
import AppKit

/// Plays polite, calm sensory auditory cues across the app.
final class AttentionSoundPlayer {
    static let shared = AttentionSoundPlayer()

    private init() {}

    /// Calm crystal chime for cycle ends and task completions.
    func playCycleEndChime() {
        Playback.play(name: "Glass", repeats: 1)
    }

    /// Calm, gentle reminder sound for Focus Interval Alarms.
    /// Uses a serene, polite sound rather than harsh alerts.
    func playAlarmBell() {
        Playback.play(name: "Blow", repeats: 1)
    }

    /// Subtle soft chime.
    func playAttentionBurst() {
        Playback.play(name: "Purr", repeats: 1)
    }
}

private enum Playback {
    static func play(name: NSSound.Name, repeats: Int) {
        guard let sound = NSSound(named: name) else {
            return
        }
        sound.volume = 0.65
        for i in 0..<max(1, repeats) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                sound.play()
            }
        }
    }
}