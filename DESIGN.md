# DESIGN.md — Technical & Visual Design Spec

> Companion to `PRD.md`. PRD says what to build and why; this file says exactly how. If PRD and DESIGN ever conflict, PRD's functional requirement wins on scope, this file wins on implementation detail. Every value below is a literal you should use unless a comment says "tune this."

---

## 1. Project structure

```
Focus/
  FocusApp.swift                 // @main entry point, App lifecycle, sets LSUIElement
  Info.plist                     // LSUIElement = true
  App/
    AppDelegate.swift            // NSApplicationDelegate for NSStatusItem + NSPanel bootstrapping
    StatusBarController.swift    // owns NSStatusItem, icon state rendering
    FloatingPanel.swift          // NSPanel subclass (see §2)
    PanelController.swift        // owns the FloatingPanel instance, position/size persistence
  Models/
    Task.swift                   // Task struct (see §4)
    Attachment.swift             // LinkAttachment / ImageAttachment (see §4)
    TimerPreset.swift            // TimerPreset struct (see §4)
    TimerSession.swift           // runtime timer state (see §4)
    AppSettings.swift            // Settings struct (see §4)
  Stores/
    TaskStore.swift              // ObservableObject, owns [Task], persistence via JSONStore
    SettingsStore.swift          // ObservableObject, owns AppSettings, persistence via JSONStore
    JSONStore.swift              // generic load/save-to-disk helper (see §5)
  Engines/
    TimerEngine.swift            // state machine: focus/break/longBreak, pause/resume/skip/reset
    CaptureClassifier.swift      // NSDataDetector + NSPasteboard inspection logic (see §6)
    ReminderScheduler.swift      // two-stage escalation logic, UserNotifications wiring (see §7)
    WhatNowSelector.swift        // FR-14 deterministic single-pick selection rule (see §11)
  Views/
    PanelRootView.swift          // top-level SwiftUI view hosted in the NSPanel
    QuickAddView.swift
    TaskListView.swift
    TaskRowView.swift
    TimerView.swift              // the ring/disc visual (see §8)
    SettingsView.swift
    Components/
      GlowModifier.swift         // reusable SwiftUI ViewModifier for glow effect (see §9)
      RippleModifier.swift       // reusable SwiftUI ViewModifier for ripple effect (see §9)
  Resources/
    Assets.xcassets              // menu bar icon variants, app icon
    UserFacingStrings.swift      // FR-12 RSD-safe copy — single source for lateness/skip/reset strings (see §12)
```

Keep this structure exactly — a build agent working phase-by-phase should be able to predict file locations without re-deriving architecture each phase.

---

## 2. Floating panel exact configuration (FR-2, FR-3)

```swift
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect, contentView: NSView) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = true
        self.becomesKeyOnlyIfNeeded = true
        self.minSize = NSSize(width: 320, height: 400)   // matches FR-2.2 minimum
        self.contentView = contentView
        self.isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }   // needed so text fields inside can receive input
    override var canBecomeMain: Bool { false }
}
```

**Pin (always-on-top) behavior toggles two properties at runtime**, not at init:

```swift
func setPinned(_ pinned: Bool) {
    self.level = pinned ? .statusBar : .normal
    self.collectionBehavior = pinned
        ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        : [.moveToActiveSpace]
}
```

- `.statusBar` level is what actually renders above full-screen apps on separate Spaces — `.floating` alone does NOT reliably beat full-screen apps; use `.statusBar` for the pinned state specifically per FR-3.1.
- Persist `pinned` boolean and `contentRect` (position+size) via `SettingsStore` (see §4/§5); restore both on `PanelController` init before the panel is shown for the first time.

**Menu bar icon → panel toggle** lives in `StatusBarController`, using `NSStatusItem.button.action` to call `PanelController.toggle()`. Do not use `MenuBarExtra` for this — it does not give you a customizable NSPanel-backed window with the pin/resize/always-on-top behavior FR-3 requires; it only gives a dismiss-on-click-outside popover, which conflicts with FR-3 directly.

---

## 3. Menu bar icon states (FR-1.3, ties into FR-7 Stage 1)

Use SF Symbols with `NSImage` template rendering so the icon respects light/dark menu bars, then apply a tint override only when a colored state is active (tint breaks "template" auto-adaptation, which is intentional for the colored states below).

| State | Symbol | Tint | Motion |
|---|---|---|---|
| Idle (no timer running) | `checklist` | none (template/monochrome) | none |
| Focus running | `timer` | none (template/monochrome) | none — steady, don't animate during normal focus time, that would itself be a distraction per §2 of PRD |
| Break running | `cup.and.saucer.fill` | none (template/monochrome) | none |
| Reminder pending (Stage 1 of FR-7) | same symbol as the cycle that just ended | Accent color from §9 palette | gentle pulse: scale 1.0→1.08→1.0 over 1.2s, repeating until acknowledged or Stage 2 fires |

Icon updates are driven by `TimerEngine`'s published state via Combine/`@Observable`; `StatusBarController` observes and re-renders on change. Do not poll.

---

## 4. Data models (exact fields)

```swift
struct Task: Identifiable, Codable {
    let id: UUID
    var title: String
    var isComplete: Bool
    var createdAt: Date
    var dueDate: Date?              // populated by CaptureClassifier, editable by user
    var linkAttachments: [LinkAttachment]
    var imageAttachments: [ImageAttachment]
    var size: TaskSize?              // nil unless daily-cap mode (FR-11) is enabled and user tags it
    var sortOrder: Int               // for manual drag-reorder persistence
    var framing: TaskFraming?         // FR-13: user-applied motivational lever, nil by default
    var firstStep: String?            // FR-15: optional "next tiny step" text, nil by default
}

enum TaskFraming: String, Codable {
    case quickWin        // challenge/competition lever — surfaces first in "What now" (FR-14)
    case doFirstNextSession  // novelty lever — pinned as next session's suggested linked task
    // Note: "Self-deadline" is NOT a case here — applying that lever just sets/edits `dueDate`
    // directly, it doesn't need its own enum case since urgency IS the dueDate field.
}

enum TaskSize: String, Codable { case big, medium, small }

struct LinkAttachment: Identifiable, Codable {
    let id: UUID
    let url: URL
    var fetchedTitle: String?       // nil until best-effort fetch completes; UI falls back to raw url string
    var faviconData: Data?          // nil until fetched
}

struct ImageAttachment: Identifiable, Codable {
    let id: UUID
    let imageFileName: String       // stored as a file in the app's support directory, not inline base64
}

struct TimerPreset: Identifiable, Codable {
    let id: UUID
    var name: String                 // e.g. "Low energy", "Normal", "Deep work"
    var focusMinutes: Int
    var breakMinutes: Int
    var longBreakMinutes: Int
    var cyclesBeforeLongBreak: Int    // default 4
}

enum TimerPhase: String, Codable { case focus, breakShort, breakLong, idle }

final class TimerSession: ObservableObject {
    @Published var phase: TimerPhase = .idle
    @Published var remainingSeconds: Int = 0
    @Published var isPaused: Bool = false
    @Published var completedFocusCyclesToday: Int = 0
    var activePreset: TimerPreset
    var linkedTaskId: UUID?          // nil if standalone session
}

struct AppSettings: Codable {
    var pinnedByDefault: Bool = false
    var panelFrame: CGRect? = nil                     // persisted position/size, nil = use default
    var reminderEscalationDelaySeconds: Int = 30
    var snoozeLengthMinutes: Int = 5
    var stimulationIntensity: StimulationIntensity = .standard
    var dailyCapEnabled: Bool = false
    var presets: [TimerPreset] = TimerPreset.defaults  // see below
}

enum StimulationIntensity: String, Codable { case gentle, standard, high }

extension TimerPreset {
    static var defaults: [TimerPreset] {
        [
            TimerPreset(id: UUID(), name: "Low energy", focusMinutes: 10, breakMinutes: 5, longBreakMinutes: 15, cyclesBeforeLongBreak: 4),
            TimerPreset(id: UUID(), name: "Normal", focusMinutes: 20, breakMinutes: 5, longBreakMinutes: 15, cyclesBeforeLongBreak: 4),
            TimerPreset(id: UUID(), name: "Deep work", focusMinutes: 45, breakMinutes: 10, longBreakMinutes: 20, cyclesBeforeLongBreak: 4),
        ]
    }
}
```

---

## 5. Data layer / persistence (v1 default: JSON on disk)

- `JSONStore<T: Codable>` generic helper: `load(from filename: String) -> T?` and `save(_ value: T, to filename: String)`, writing to `FileManager.default.urls(for: .applicationSupportDirectory, ...)` under a `Focus/` subfolder.
- Two files: `tasks.json` (array of `Task`) and `settings.json` (single `AppSettings`).
- Images referenced by `ImageAttachment.imageFileName` are stored as separate files in `Focus/Images/` under the same Application Support directory — do not inline image bytes into `tasks.json`.
- Save triggers: debounced write (e.g. 500ms after last change) on any mutation to `TaskStore` or `SettingsStore`, plus an explicit save on app termination (`applicationWillTerminate`).
- No migrations framework needed for v1 — if this becomes SwiftData later (see PRD §7 open decision), that's a v2 migration concern, not now.

---

## 6. Capture classification logic (FR-5)

`CaptureClassifier.classify(pasteboard: NSPasteboard) -> ClassifiedContent` returns a struct bundling whatever it found:

```swift
struct ClassifiedContent {
    var titleText: String?          // remaining plain text after stripping matched date phrase
    var url: URL?
    var imageFileName: String?      // already written to disk by this point
    var dueDate: Date?
}
```

Order of operations:
1. Check `pasteboard.types` for `.tiff`/`.png` image data first — if present, write to disk immediately (`ImageAttachment` file), record filename.
2. Check for `.URL` type or a string containing a URL pattern — extract with `NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)`.
3. Run `NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)` against the remaining plain text to extract a natural-language date/time. If found, remove the matched substring from the text used for the title (per PRD FR-5.1 — don't show the date phrase twice).
4. Whatever plain text remains (after stripping a matched URL and matched date phrase) becomes `titleText`. If nothing remains (e.g., the paste was ONLY a date phrase), fall back to a sensible default title like "New task" — do not leave title empty (Task.title is non-optional).
5. Link title/favicon fetch: fire an async `URLSession` fetch of the page `<title>` tag and favicon AFTER the task/chip is already created and shown with the raw URL — never block task creation on network I/O (this satisfies FR-5.3's "never blocks" requirement).

This same classifier is invoked from both (a) the quick-add field's paste handler and (b) drag-and-drop `onDrop` handlers on `TaskRowView` — do not duplicate the logic, both call into `CaptureClassifier`.

---

## 7. Reminder escalation (FR-7)

`ReminderScheduler` is driven by `TimerEngine` firing a "cycle ended" event.

1. **Stage 1 (t=0):** `StatusBarController` immediately switches icon to reminder-pending state (§3 table) and starts the pulse animation.
2. **Stage 2 (t = `settings.reminderEscalationDelaySeconds`):** if not acknowledged (user hasn't opened the panel or tapped a notification action), post a `UNNotificationRequest` via `UserNotificationCenter` with:
   - Title: "Focus session done" (or "Break's over", matching which phase ended)
   - Body: linked task title if any, else generic
   - Actions (via `UNNotificationCategory`): "Start Break" / "Start Focus" (context-dependent), "Snooze", "Dismiss"
3. **Acknowledgement** = user opens the panel OR taps any notification action. On acknowledgement, stop the pulse, revert icon to idle/next-phase state.
4. **Snooze** re-arms the same two-stage timer after `settings.snoozeLengthMinutes`.
5. There is no Stage 3 — do not add a repeating/escalating loop beyond this. This is a hard requirement (PRD FR-7.2), not a placeholder to expand later without a new decision.

### Reminder visual variants (for anti-habituation, FR-7.4)

Rotate deterministically through this list by `completedFocusCyclesToday % variants.count` (not random — deterministic keeps it debuggable/testable):

| Variant | Glow color (from palette §9) | Pulse pattern |
|---|---|---|
| A | Accent Teal | scale pulse, 1.2s period |
| B | Accent Coral | opacity pulse (0.6↔1.0), 1.0s period |
| C | Accent Violet | scale + opacity combined, 1.5s period |

All three must respect the `stimulationIntensity` amplitude scaling from §9 regardless of which variant is active.

---

## 8. Timer visual spec (FR-6.3)

The primary timer visual is a circular ring:
- Outer static ring: 2pt stroke, 20% opacity of the current phase's accent color (Focus = Accent Teal, Break = Accent Coral).
- Inner progress arc: 4pt stroke, full opacity of the phase accent color, drawn via `Circle().trim(from: 0, to: progress)` where `progress = remainingSeconds / totalSeconds`, animated with `.animation(.linear(duration: 1), value: progress)` ticking once per second — NOT a discrete jump, it should read as continuously draining even though it updates once/sec.
- Direction: the arc SHRINKS as time elapses (starts full circle, drains to nothing at zero) — this is the "shrinking disc" mechanism from the PRD research section, not a filling-up bar.
- Digital time (mm:ss) is shown as small centered text inside the ring — secondary, not primary, per FR-6.3.
- Linked task title (if any) shown below the ring, small text, truncated with ellipsis if long.

---

## 9. Visual language / palette / animation specs (FR-9)

**Palette (dark-first):**
- Background: `#121214` (panel base), `#1B1B1F` (card/row surface)
- Text primary: `#F2F2F5`, text secondary: `#9A9AA2`
- Accent Teal (Focus): `#3DDC97`
- Accent Coral (Break): `#FF7A6B`
- Accent Violet (reminder variant C / pin-engaged state): `#9B7BFF`

**Glow effect** (`GlowModifier.swift`): implemented as a `.shadow(color: accentColor.opacity(intensityMultiplier), radius: glowRadius)` stacked twice (a tight radius + a wide radius) for a soft bloom look, not a hard-edged shadow. `glowRadius` and opacity both scale by `stimulationIntensity`:
- `.gentle`: radius 4/12, opacity multiplier 0.35
- `.standard`: radius 6/18, opacity multiplier 0.55
- `.high`: radius 10/28, opacity multiplier 0.8

**Ripple effect** (`RippleModifier.swift`): on trigger (task completion, pin engage), overlay an expanding `Circle().stroke()` from the trigger point, scaling from 0.1x to ~2.5x scale while fading opacity 0.8→0 over 500ms (`.gentle`), 650ms (`.standard`), 800ms (`.high`) — higher intensity = slightly slower/larger so it reads as more pronounced, not just longer for its own sake.

**Where animation is allowed to fire (exhaustive — do not add more per FR-9.2):**
1. Menu bar icon reminder pulse (§3, §7)
2. Task row on completion: checkbox fill + ripple modifier + row briefly (300ms) shifts background toward Accent Teal at low opacity, then settles to a "completed" dimmed style
3. Timer ring on phase transition (focus→break or vice versa): brief glow flash on the ring using the new phase's accent color
4. Pin toggle button: glow modifier applied while `pinned == true` (persistent, but implemented as a static glow, not a looping animation — a static glow is not "animation" in the FR-9.2 continuous-distraction sense, it's a state indicator)

Nothing else animates. No idle/ambient motion on the task list, background, or quick-add field.

**Sound:** only at `.standard` and `.high` intensity, on Stage 2 notification only (never on every micro-interaction) — a single short, soft chime, not a jingle. `.gentle` intensity = no sound, visual-only.

---

## 11. "What now" selection rule (FR-14) — exact, deterministic, no black box

Implement as a pure function `func whatNow(tasks: [Task], excluding: UUID?) -> Task?` in a new `Engines/WhatNowSelector.swift`:

```swift
func whatNow(tasks: [Task], excluding: UUID? = nil) -> Task? {
    let candidates = tasks.filter { !$0.isComplete && $0.id != excluding }
    let today = Calendar.current.isDateInToday

    // Priority 1: framed "quickWin" tasks due today or overdue (or with no due date at all —
    // a quick win with no date is still a quick win)
    if let quickWin = candidates.first(where: {
        $0.framing == .quickWin && ($0.dueDate == nil || $0.dueDate! <= Date())
    }) { return quickWin }

    // Priority 2: smallest-sized task due today (requires FR-11 size tagging to be in use;
    // if the user never tags sizes, this tier simply has no matches and falls through)
    if let smallToday = candidates
        .filter({ $0.size == .small && $0.dueDate != nil && today($0.dueDate!) })
        .first { return smallToday }

    // Priority 3: oldest uncompleted task by createdAt (simple FIFO fallback — always has an
    // answer as long as candidates is non-empty)
    return candidates.min(by: { $0.createdAt < $1.createdAt })
}
```

- "Re-roll" (FR-14.1's "different one" affordance) calls the same function passing the just-shown task's `id` as `excluding`, so it can never repeat back-to-back. If `candidates` is empty after exclusion, re-show the same task (there's nothing else) rather than showing nothing.
- Do not add machine-learning ranking, recency weighting, or any other implicit heuristic beyond this three-tier rule — FR-14.2 explicitly requires the user be able to predict the outcome, which a learned/opaque ranker would break.

---

## 12. RSD-safe copy module (FR-12)

Create `Resources/UserFacingStrings.swift` (or a `.strings`/`.stringsdict` catalog if you prefer standard localization tooling — either is fine, but it must be the ONE place these strings are authored). Every view that needs to communicate a lateness/skip/reset/overdue/streak-break state pulls from this file — no inline string literals for these categories anywhere else in `Views/`.

Minimum required entries and their exact required tone (do not soften further into vagueness, and do not sharpen into alarm — match this register):

```swift
enum RSDSafeCopy {
    static let sessionMissed = "That session didn't happen — want to try a shorter one?"
    static let sessionSkipped = "Skipped. Ready when you are."
    static let taskOverdueLabel = "Still open"              // NOT "Overdue" as a standalone alarming label
    static let streakBrokenNeutral = "Starting a new streak today"
    static let timerReset = "Reset"                          // neutral, not "gave up" / "quit"
    static let allTasksIncompleteEndOfDay = "A few are still open — they'll be here tomorrow"
}
```

Pair this with the visual rule from FR-12.2: any UI element that surfaces one of these strings uses a neutral badge color (`#3A3A40` background / `#C8C8D0` text from the palette family in §9 — do NOT introduce a red/orange alert color anywhere in the app; there is no alert color in this app's palette by design).

---

## 13. Task framing UI (FR-13) and Next Tiny Step field (FR-15)

- **Framing menu**: a small "..." or long-press context menu on `TaskRowView`, three items — "Set a deadline" (opens the existing due-date editor from FR-4/FR-5), "Mark as quick win" (toggles `task.framing = .quickWin`, or nil if already set — it's a toggle, not a one-way flag), "Do first next session" (sets `task.framing = .doFirstNextSession`; when `TimerEngine` starts a new session with no explicit `linkedTaskId` already chosen, it checks for a task with this framing first before falling back to no-linked-task).
- Framing badge: a single small icon on the task row (⚡ for quickWin, ⏭ for doFirstNextSession — exact glyphs are a placeholder, swap for real iconography during Phase 8, but keep it to ONE small glyph, not a text label, to avoid row clutter).
- **First step field**: inline text field on `TaskRowView`, revealed via the same "..." menu ("Add first step") or shown permanently as a smaller secondary line under the title if already set — a build agent's implementation choice, but once set it must always be visible on the row without a extra tap (FR-15 exists specifically to remove a step, not add one).
- In `TimerView`, when `TimerSession.linkedTaskId` matches a task with a non-nil `firstStep`, render that text in a distinct, slightly larger style ABOVE the linked task's title (per FR-15.2) — this is the one exception to "timer view only shows task title small," because the whole point is surfacing the first action before the title.

---

## 14. Presence glow cue (FR-16)

- A new, distinct visual state — do not reuse `GlowModifier`'s reminder-pulse parameters (§7/§9); this must read as calm, not urgent, or it will be confused with a reminder.
- Applied to a small dedicated element in `TimerView` (e.g., a thin ring segment or a soft dot near the timer, NOT the timer ring itself, which is reserved for time-remaining per §8) — steady state, slow breathing animation: opacity 0.5↔0.75 over a 4-second period, using Accent Violet (`#9B7BFF`) at low overall opacity regardless of `stimulationIntensity` (this cue is intentionally NOT scaled by intensity setting — it should always read as calm/ambient, never amplified to "high," since amplifying calm-presence into something loud would defeat its purpose).
- Only rendered while `TimerSession.phase == .focus` and `isPaused == false`. Disappears immediately (no fade-out animation needed — its absence is itself the natural signal) when the session ends, pauses, or switches to a break phase.
- No text, no icon-of-a-person, no avatar — literally just the glow described above. This is a deliberate, minimal implementation per the honesty note in PRD §2A; do not "upgrade" this into a character or mascot without a new decision — that would change what the feature is (a presence cue) into something else (a simulated companion), which carries different UX/ethical weight the PRD did not sign off on.

---

## 15. Non-negotiable engineering constraints (cross-cutting)

- No third-party dependencies for v1 (no SPM packages) — everything specified above is achievable with SwiftUI + AppKit + Foundation + UserNotifications.
- All persistence must survive force-quit (debounced save is not a substitute for save-on-terminate; implement both, per §5).
- `TimerEngine` must be the single source of truth for phase/remaining time — views and the status bar controller only observe it, never maintain their own copies of countdown state.
- Every user-facing duration (focus/break/long-break/escalation delay/snooze) must read from `AppSettings`/`TimerPreset` at the moment it's used — never hardcode a duration in a view or engine method body.
