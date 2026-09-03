import Foundation
import AppKit

/// Plays the attention sounds used across the app.
///
/// - Pomodoro/Timer cycle-end: a short chime, silenced in `.gentle` mode per
///   DESIGN.md §9's intensity-scaling rule.
/// - Focus Interval Alarms: a distinct, louder, more insistent bell/buzz that is
///   ALWAYS played regardless of `stimulationIntensity` (§3.3 — a deliberate,
///   documented exception to the intensity rule).
final class AttentionSoundPlayer {
    static let shared = AttentionSoundPlayer()

    private init() {}

    /// Short, polite chime for Pomodoro/Timer cycle-ends.
    func playCycleEndChime() {
        Playback.play(name: "Glass", repeats: 1)
    }

    /// The Focus Interval Alarm's distinct, louder, insistent bell (§3.3).
    /// Three rapid strikes read as "louder/more insisting" than the single chime.
    func playAlarmBell() {
        Playback.play(name: "Sosumi", repeats: 3)
    }

    /// A louder still variant for the full-screen attention overlay (Phase 15).
    func playAttentionBurst() {
        Playback.play(name: "Funk", repeats: 2)
    }
}

private enum Playback {
    static func play(name: NSSound.Name, repeats: Int) {
        guard let sound = NSSound(named: name) else {
            NSSound.beep()
            return
        }
        for i in 0..<max(1, repeats) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.35) {
                sound.play()
            }
        }
    }
}