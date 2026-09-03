# V1_IMPROVEMENTS.md — Loopin: Multi-Window Rework, Memorigi-Style Todo, Focus Interval Alarms, Attention System Fix

> **Relationship to existing PRD.md / DESIGN.md:** this file does not replace those documents — it's a change-request layer on top of them, written for the same audience (a lower-capability coding agent). Where something below conflicts with the original PRD/DESIGN (notably: window architecture, and the visual palette), **this file wins**. Where this file is silent on something (data persistence approach, project structure conventions, RSD-safe copy rules, etc.), the original PRD.md/DESIGN.md still governs. Read both. Treat every acceptance criterion below as a hard requirement, not a suggestion — the previous animation/attention system was reported as "not even working," so nothing about it should be assumed to already exist correctly; rebuild it from this spec.

---

## 0. What's changing and why (read this before touching code)

The app is moving from "one floating panel with everything in it" to **one menu bar icon that opens a picker menu, which opens one of several independent windows**. This is a real architecture change, not a cosmetic one — each window (Pomodoro/Timer/Stopwatch, To-Do List, Focus Interval Alarms, Settings) is now its own `FloatingPanel` instance with its own lifecycle, independently resizable, independently closable, and NOT required to all be open at once.

Second major change: the to-do list is being redesigned to match **Memorigi** (Android to-do app) — see §4 for exactly what that means concretely, since "match the app" isn't itself a spec.

Third: a genuinely new feature, **Focus Interval Alarms** — a repeating metronome-style alarm independent of the Pomodoro timer (§3).

Fourth, and most important to get right: the attention/animation system is being rebuilt from scratch per §6, because the previous implementation didn't work. This section is intentionally the most detailed in this document.

---

## 1. Window architecture (supersedes PRD §1's single-panel model)

### 1.1 Menu bar click behavior
- Clicking the menu bar icon (`NSStatusItem`) no longer directly opens a single panel. It opens a **native `NSMenu`** (a real dropdown menu, not a custom SwiftUI popover) with exactly these items, in this order:
  1. **To-Do List**
  2. **Pomodoro / Timer / Stopwatch**
  3. **Focus Interval Alarms**
  4. — separator —
  5. **Settings**
  6. — separator —
  7. **Quit Loopin**
- Selecting an item opens (or brings to front, if already open) that window's `FloatingPanel` instance. Selecting an already-open window's item just focuses it — it does not close it or spawn a duplicate.
- Each window remembers its own position/size/pinned-state independently (four separate persisted frames, not one shared frame — extend `AppSettings` per §7).
- **Acceptance:** clicking the menu bar icon always shows the `NSMenu` (never directly opens a window); each of the 4 items opens its own independent window; opening two or more simultaneously works with no shared-state bugs (e.g., editing a task in the To-Do window while a timer runs in the Timer window, both visible at once).

### 1.2 Per-window independence
- Every window from §1.1 is its own `FloatingPanel` (same base class/config as DESIGN.md §2 — `.nonactivatingPanel`, resizable, closable, pin-able via `.statusBar` level toggle) — do not build one mega-window with tabs. The user explicitly asked for separate windows they choose between from the menu, not a tabbed single window.
- Each window has its own pin toggle in its own chrome (per-window pin state, not global).
- **Acceptance:** pinning the To-Do window does not affect the Timer window's layering; closing the Timer window leaves the To-Do window (if open) untouched.

---

## 2. Pomodoro / Timer / Stopwatch window (extends PRD FR-6)

- **2.1** This single window has a mode switcher (segmented control at the top: **Pomodoro | Timer | Stopwatch**).
  - **Pomodoro mode:** exactly the existing FR-6 behavior (focus/break cycles, editable presets, ring visual).
  - **Timer mode:** a plain single-countdown timer — user types/picks any duration, hits start, it counts down to zero once (no automatic cycle repeat, no break phase). Uses the same ring visual (DESIGN.md §8) with a single phase, no focus/break color distinction (use a neutral accent, see §6 palette).
  - **Stopwatch mode:** counts up from zero, start/pause/reset/lap (lap is optional — a simple lap list is fine, no need for anything elaborate). Ring visual is not meaningful for count-up, so Stopwatch mode shows a plain large digital readout instead of the ring (this is the one legitimate exception to "digital number is always secondary" from DESIGN.md §6 — a stopwatch has no "total" to show progress against, so there's no ring to draw).
- **2.2** Switching modes stops/resets whatever was running in the previous mode (don't try to carry a Pomodoro cycle into Stopwatch mode) — but ask via a lightweight, non-blocking confirmation only if something is actively mid-session; switching from idle is instant with no prompt.
- **2.3** All duration editing remains live/instant per the existing FR-6.4 rule — no separate spec needed here, just confirming it applies to Timer mode's single duration too.
- **Acceptance:** all three modes are reachable from one window via the switcher; each mode's start/pause/reset behaves independently; switching modes never leaves a stale countdown running in the background from the mode you left.

---

## 3. Focus Interval Alarms (new feature, new window)

This is a distinct feature from Pomodoro — a repeating "metronome" alarm meant to interrupt long stretches regardless of what task/timer is active.

- **3.1** The Focus Interval Alarms window lets the user pick ONE interval from a fixed preset list: **2, 3, 5, 10, 15, 20, 25 minutes**, plus a Start/Stop toggle.
- **3.2** Once started, the app fires an alert every N minutes, indefinitely, until the user stops it (or quits the app). This runs independently of whatever the Pomodoro/Timer window is doing — they are not mutually exclusive (a user could have a 20-min Focus Interval Alarm running WHILE also running a 45-min Pomodoro focus session; the two are unrelated features that happen to share the same alert mechanism from §6).
- **3.3** The alert itself uses the SAME attention system as every other alert in the app (§6) — menu bar pulse, the escalating notification, AND (this is the one place where a strong sound is explicitly requested and appropriate) a distinct, louder/more insistent bell or buzz sound specifically for this feature, louder by default than the standard Pomodoro cycle-end sound, because its whole purpose is a strong external interrupt for a very long the user has been made to be doing.
- **3.4** The chosen interval and running/stopped state persist across relaunch (if it was running, it resumes counting from a fresh interval on relaunch — do not try to reconstruct exact elapsed time across a full quit/relaunch, that's unnecessary complexity for what is fundamentally a "did you take a break lately" nudge).
- **Acceptance:** starting a 5-minute interval alarm fires a distinct alert every 5 minutes reliably; it continues firing while a separate Pomodoro session is independently running and alerting on its own schedule; stopping it silences future alerts immediately.

---

## 4. To-Do List window — Memorigi-style rework (supersedes/extends PRD FR-4, FR-5, FR-11 UI; FR-12/13/14/15/16 logic still applies underneath)

"Match Memorigi" is broken down here into concrete, buildable pieces — a build agent cannot "just look at the app," so treat this list as the actual spec:

### 4.1 Visual/structural language to match
- **List/section based structure:** tasks are grouped under simple headers — at minimum "Today," "Later" (or "Upcoming"), and a collapsible **"Completed"** section (§4.4) — mirroring Memorigi's Today/Upcoming/Logbook view split, rather than one flat undifferentiated list.
- **Colorful per-item accent, not a monochrome list:** each task or list/category can carry a color tag (small set of preset accent colors, not a full picker in v1) shown as a small colored dot/bar on the row — this is Memorigi's signature "colorful tasks and lists" look, distinct from a plain black-and-white checklist.
- **Icon-forward rows:** each task row supports a small leading icon/emoji (user-pickable from a small fixed set, or auto-derived from an attachment type per §4.3) rather than a bare checkbox-and-text row.
- **Swipe/quick-action affordance:** since this is macOS not a touchscreen, the equivalent is hover-revealed row actions (complete / important / delete icons fade in on hover) rather than a literal swipe gesture — same *speed of interaction* goal as Memorigi's swipe gestures, adapted to a trackpad/mouse context.
- **Clean, minimal chrome, colorful content:** background/chrome stays close to DESIGN.md's existing dark neutral palette (§9), but task content itself (color dots, icons, attachment thumbnails) is where the color lives — this mirrors Memorigi's actual balance (minimalist frame, colorful content) rather than making the whole app rainbow-colored.

> **Honesty note on exact colors:** I don't have pixel-verified hex values from Memorigi's actual screenshots to copy exactly, and copying another app's exact proprietary palette byte-for-byte also isn't something to lean on. What's specified above is the *design language* (minimal frame + colorful content + icon-forward + section-based), which is what actually makes something "feel like Memorigi." If literal color matching matters to you, take screenshots of Memorigi yourself and sample the hex values, then swap them into DESIGN.md §9's palette table — that's a five-minute task with any color picker and is a better source of truth than a description.

### 4.2 Standard todo features (the "like Google Tasks" part)
- **4.2.1** Mark important — a star/flag toggle on each task, separate from completion state. Important tasks get a small distinct indicator (filled star icon) and can optionally be filtered to show only important tasks (a simple toggle at the top of the list).
- **4.2.2** Inline rename/edit — click the title to edit in place (already required by original FR-4.3, restated here since it now interacts with §4.3's filename display).
- **4.2.3** Due dates remain as originally specified (FR-4.2/FR-5.1) — nothing changes there, they just now render as a small badge on the Memorigi-style row instead of plain text.

### 4.3 File/image attachment-as-task-display (new behavior)
- **4.3.1** Dragging a file or image onto a task (existing or a blank "add task" drop target) attaches it as a **document attachment**, and the task row's display changes to show that attachment prominently — e.g., an image attachment shows a thumbnail preview inline in the row (not just a small icon), a document/file attachment shows a file-type icon + filename inline in the row, in place of what would otherwise be a bare text row.
- **4.3.2** When the user clicks into the task's name to rename/edit it, the edit field shows the current task name AND a small non-editable tag next to it indicating the attached file's type (e.g., a small "PNG" / "PDF" / "DOCX" pill next to the editable name field) — so the user can rename the task without losing visibility of what kind of file is attached. This tag is derived from the file extension/UTType, not user-entered.
- **4.3.3** A task can have both a title AND an attachment at the same time — attaching a file does not replace/require clearing the title. If a file is dropped onto a task with no title yet, auto-fill the title from the filename (without extension), same spirit as PRD FR-5's "auto-derive title from pasted content" rule, editable afterward like any title.
- **4.3.4** This extends (does not replace) the existing `ImageAttachment` model — add a general `FileAttachment` type alongside it (see §7) for non-image documents, since PRD's original model only covered links and images.
- **Acceptance:** dropping a PNG onto a task shows a thumbnail in the row immediately; dropping a PDF shows a file icon + "loopin-notes.pdf" inline; editing either task's name shows the name field plus a small non-editable type tag; renaming never deletes the attachment.

### 4.4 Completed section + cleanup
- **4.4.1** Completed tasks move to a distinct, collapsible **"Completed"** section at the bottom of the list (collapsed by default, shows a count, e.g. "Completed (7)") rather than disappearing or staying inline with active tasks.
- **4.4.2** Every task row (active or completed) has a visible delete button (an icon, revealed on hover per §4.1, not requiring a context-menu dig) that removes it immediately — pair with a brief undo affordance (a few seconds' toast/snackbar-style "Deleted — Undo") rather than a confirmation dialog, consistent with PRD's existing "no confirmation dialogs" pattern (FR-4.3/FR-6.6).
- **4.4.3** A single "Clear completed" action (button or link at the top of the Completed section) permanently removes all completed tasks at once. This one DOES warrant a lightweight confirmation (it's a bulk irreversible action, unlike single-item delete which has undo) — a simple inline "Clear 7 completed tasks? [Clear] [Cancel]" is sufficient, no modal dialog needed.
- **Acceptance:** completing a task visibly moves it into the Completed section (with the existing completion animation from DESIGN.md §9 still firing); deleting any single task offers undo; "Clear completed" empties the section in one action after its lightweight confirmation.

---

## 5. macOS desktop widget (new)

- **5.1** Build a WidgetKit widget (macOS 14+ desktop widgets, via a Widget Extension target added to the existing app) showing the current task list (or a configurable subset — "Today" tasks is the sensible default).
- **5.2** The widget must reflect new tasks added from the main app **live** — implement this via a shared `App Group` container (shared `UserDefaults`/shared file container between the main app target and the widget extension) plus a `WidgetCenter.shared.reloadTimelines(ofKind:)` call fired every time `TaskStore` saves, so the widget refreshes promptly rather than only on its normal OS-throttled refresh schedule.
- **5.3** Widget is read-only display for v1 — no adding/completing tasks directly from the widget (macOS desktop widgets have limited interactivity; don't over-scope this for v1, it's a visibility surface, not a second UI to build/maintain).
- **Acceptance:** adding a task in the To-Do window causes the desktop widget to visibly update without the user needing to manually refresh, remove, or re-add the widget.

---

## 6. Attention/animation system — full rebuild (this section supersedes DESIGN.md §9 wherever they conflict)

**Context: the previous implementation was reported broken.** Do not assume any existing glow/ripple code works — verify each piece against this spec from scratch, and treat a "looks like it's wired up" code review as insufficient; actually trigger each case listed in §6.4 and confirm visually.

### 6.1 What this system must do (restating the ask precisely)
Every one of these events must produce a short, attention-catching visual (and where specified, audio) effect, strong enough to notice even if the user is not looking at the Loopin app at all — including while another app is in full-screen mode (e.g., a full-screen video):
- A Pomodoro focus session ends
- A Pomodoro break session ends
- A Focus Interval Alarm fires (§3)
- A plain Timer-mode countdown reaches zero
- A task is marked complete

### 6.2 Reconciling this with the original restraint principle (read before building)
The original PRD (§2, §9) deliberately avoided forced full-screen takeovers, because the ADHD research it was built on found that overstimulating, blocking interrupts backfire. **That principle still holds and is not being reversed here** — what's being fixed is that the *ambient, non-blocking* version of this system apparently isn't actually working, not that it should be replaced with a blocking one. So: the effect specified below must be simultaneously (a) visible over a full-screen app, and (b) non-blocking — the user's clicks/keystrokes must still go through to whatever app is frontmost; the effect is a visual/audio layer, not an interactive window that steals focus or intercepts input.

### 6.3 Technical mechanism (how to actually render over a full-screen app)
This is the part that likely explains why it "wasn't even working" — a normal `NSPanel` at `.floating` or even `.statusBar` level does NOT reliably paint over another app's dedicated full-screen Space. To actually appear over a full-screen app, do this:

```swift
final class AttentionOverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver              // renders above full-screen-app Spaces
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true          // CRITICAL: click-through, never intercepts input
        self.hasShadow = false
        self.contentView = NSHostingView(rootView: AttentionOverlayView())
    }
}
```
- `ignoresMouseEvents = true` is the load-bearing line for the "must not block the user" requirement in §6.2 — without it, this becomes exactly the forced-interrupt pattern the original PRD ruled out.
- Instantiate one `AttentionOverlayWindow` per active `NSScreen` (loop `NSScreen.screens`) so it works correctly on multi-monitor setups, and re-create the set if the screen configuration changes (`NSApplication.didChangeScreenParametersNotification`).
- The overlay window is created on-demand when an alert fires and torn down after its effect finishes (§6.4 duration) — it should not exist as a permanent invisible window sitting open at all times.

### 6.4 The visual effect itself
`AttentionOverlayView` (SwiftUI, hosted per §6.3) renders, for a short fixed duration (2.5–3.5 seconds total, not longer — this is meant to catch attention and then get out of the way, not linger):
1. **Edge glow:** a soft colored glow inset from all four screen edges (implemented as a `RoundedRectangle` stroke with a heavy blur/shadow, color-matched to the event type per the table below), fading in over ~300ms, holding, then fading out over the remaining duration. This is the primary "even out of the corner of your eye" cue.
2. **Sliding message:** a small pill/card (not full-width, not full-screen — modest size, e.g. ~320pt wide) slides in from one screen edge (top or side — pick one consistently, e.g. top-center), shows a short message (from the RSD-safe copy module, DESIGN.md §12 — e.g. "Break time" / "Back to focus" / "Task done"), holds briefly, then slides back out. It never requires a click to dismiss — it's timed, matching §6.2's non-blocking requirement.
3. Both elements use the glow/ripple visual language and palette already defined in DESIGN.md §9 (Accent Teal for focus-related, Accent Coral for break-related) — do not invent a new color system for this, reuse the existing accent palette so the whole app stays visually consistent. Focus Interval Alarms (§3) use Accent Violet to visually distinguish them from Pomodoro-driven alerts.
4. Sound: per DESIGN.md §9's existing intensity-scaling rule (`.gentle` = no sound, `.standard`/`.high` = a short chime) for Pomodoro/Timer events, EXCEPT Focus Interval Alarms (§3.3), which always play their distinct louder bell/buzz regardless of `stimulationIntensity`, since a strong interrupt is explicitly the point of that specific feature (this is a deliberate, documented exception to the intensity-scaling rule — do not apply gentle-mode silencing to Focus Interval Alarms).
5. **Dock icon** also gets a lightweight cue in parallel (bounce once via `NSApp.requestUserAttention(.informationalRequest)`) — this is a standard, low-effort, OS-native way to reinforce the same "something happened" signal without building custom dock UI.

| Event | Overlay glow color | Message text (from RSDSafeCopy, extend DESIGN.md §12) |
|---|---|---|
| Focus session ended | Accent Teal | "Focus session done" |
| Break ended | Accent Coral | "Break's over — ready when you are" |
| Focus Interval Alarm fires | Accent Violet | "Interval check-in" |
| Timer-mode countdown reaches zero | Accent Teal | "Time's up" |
| Task marked complete | Accent Teal (brief, smaller-scale variant — reuse the existing in-row completion animation from DESIGN.md §9 for this one; task completion does NOT need the full-screen overlay treatment, only the four timer/alarm events above do, since task completion is already something the user is actively looking at when it happens) | n/a — row-level only |

- **Acceptance:** triggering any of the four full-screen-worthy events while another app is in full-screen mode produces the edge glow + sliding message visibly on top of that full-screen app, without the user's next click/keystroke being intercepted by Loopin; the effect disappears on its own within ~3.5 seconds; task completion continues to use only the existing in-row animation, not a full-screen overlay.

### 6.5 Debugging checklist for "why didn't this work before"
Before declaring this done, explicitly verify each of these, since any one of them silently breaks full-screen-overlay behavior:
- Window `level` is `.screenSaver`, not `.floating` or `.statusBar` (the latter two do not reliably beat a full-screen app's dedicated Space).
- `collectionBehavior` includes `.fullScreenAuxiliary` (without this, the window simply won't be assigned to the full-screen Space at all).
- `ignoresMouseEvents` is `true` (without this, the invisible-but-clickable overlay can silently eat clicks meant for the app underneath, which can look like "random unresponsiveness" rather than an obviously broken effect).
- The app has the necessary entitlement/capability if sandboxed — for v1 (per PRD §5, sandboxing is not yet a v1 requirement) this shouldn't be a blocker, but note it for whenever App Store hardening (PRD §7 stretch goal) happens.

---

## 7. Data model additions (extends DESIGN.md §4)

```swift
struct FileAttachment: Identifiable, Codable {
    let id: UUID
    let fileName: String          // stored under Application Support, same pattern as ImageAttachment
    let fileTypeTag: String       // derived from UTType, e.g. "PDF", "DOCX" — shown per §4.3.2, never user-edited
}

// Task gains:
//   var fileAttachments: [FileAttachment]   // alongside existing linkAttachments/imageAttachments
//   var isImportant: Bool = false           // §4.2.1
//   var colorTag: TaskColorTag? = nil       // §4.1 per-item accent

enum TaskColorTag: String, Codable, CaseIterable {
    case teal, coral, violet, amber, neutral   // small fixed preset set, not a full color picker in v1
}

struct FocusIntervalAlarmSettings: Codable {
    var intervalMinutes: Int = 10     // one of {2,3,5,10,15,20,25}, validated at the UI layer
    var isRunning: Bool = false
}

// AppSettings gains:
//   var windowFrames: [String: CGRect]   // keyed "todo" / "timer" / "alarms" / "settings" — replaces the
//                                          // single panelFrame from the original DESIGN.md, per §1.2
//   var windowPinned: [String: Bool]     // per-window pin state, same keys as above
//   var focusIntervalAlarm: FocusIntervalAlarmSettings
```

- `TimerSession` (DESIGN.md §4) gains a `mode: TimerMode` field (`enum TimerMode: String, Codable { case pomodoro, timer, stopwatch }`) per §2.1.
- Migration note: `AppSettings.panelFrame` (singular, from the original DESIGN.md) is being replaced by `windowFrames` (plural, keyed dictionary). Write a small one-time migration (same pattern as the Loopin directory-rename migration already shipped) that, if an old singular `panelFrame` exists on first launch after this update, seeds `windowFrames["todo"]` from it (since the To-Do list was effectively "the app" before this multi-window change) rather than discarding it.

---

## 8. Phased build plan for this revision

Treat this as continuing on from the original PRD's Phase 9 — these are Phases 10+, same gating rule (finish and verify one before starting the next).

### Phase 10 — Window architecture migration (§1)
- Convert the menu bar click from single-panel-toggle to the `NSMenu` picker.
- Refactor `PanelController` to manage N independent `FloatingPanel` instances instead of one, with the `windowFrames`/`windowPinned` dictionary persistence from §7 (including the migration note).
- **Exit criteria:** §1.1 and §1.2 acceptance criteria pass; existing To-Do content still opens correctly under the new architecture (this is a refactor, not a data-loss event — verify existing tasks/settings survive).

### Phase 11 — Timer/Stopwatch modes (§2)
- Add the mode switcher and Stopwatch/Timer modes alongside existing Pomodoro logic.
- **Exit criteria:** §2 acceptance criteria pass.

### Phase 12 — Focus Interval Alarms (§3)
- New window, new engine (can reuse `TimerEngine`'s underlying repeating-timer plumbing, but this is a conceptually separate always-on-until-stopped feature, not a Pomodoro preset — keep it a distinct type per §7).
- **Exit criteria:** §3 acceptance criteria pass, including running concurrently with an active Pomodoro session.

### Phase 13 — Memorigi-style To-Do rework (§4)
- Section-based list (Today/Later/Completed), color tags, icon-forward rows, hover-revealed row actions, important-flag, file-attachment-as-row-display, delete+undo, clear-completed.
- **Exit criteria:** §4.1 through §4.4 acceptance criteria all pass.

### Phase 14 — Desktop widget (§5)
- Add Widget Extension target, App Group, live-reload wiring.
- **Exit criteria:** §5 acceptance criteria pass.

### Phase 15 — Attention system rebuild (§6)
- Build `AttentionOverlayWindow`/`AttentionOverlayView` per §6.3–6.4 exactly, run the §6.5 debugging checklist explicitly (don't skip it even if it "looks right"), wire all five trigger events from §6.1.
- **Exit criteria:** §6.4's acceptance criterion passes for all four full-screen-worthy events, tested specifically with another app in actual full-screen mode (not just windowed) — this is the scenario that was reportedly broken before, so it's the one that must be explicitly re-tested, not assumed fixed.

### Phase 16 — Full regression pass (extends PRD Phase 9)
- Re-run every acceptance criterion from PRD.md §4 AND this document end-to-end, including relaunch-mid-session persistence checks for the new per-window frames/pin states and the Focus Interval Alarm running-state.
- **Exit criteria:** everything passes with no regressions, including on a secondary/full-screen test pass for §6.
