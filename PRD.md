# PRD — Focus (working title): ADHD-Aware Menu Bar Todo + Pomodoro App for macOS

> **How to read this document if you are the build agent:** This PRD is self-contained. Every requirement below is final unless a "DECISION NEEDED" tag says otherwise. Do not invent scope beyond what is written. Build phases at the bottom are sequential and gated — do not start Phase N+1 until Phase N's acceptance criteria all pass. Pair this file with `DESIGN.md` for exact technical implementation (window configs, data models, file structure, visual specs). This file tells you **what** and **why**; `DESIGN.md` tells you **how**.

---

## 1. Product summary

A native macOS **menu-bar-resident** application that combines:
1. A todo list that auto-organizes anything dropped or pasted into it (links, images, dates/times), and
2. A flexible, visually-ambient Pomodoro-style focus/break timer,

designed around documented ADHD cognitive patterns: **time blindness**, **task-initiation failure**, **working-memory capture loss**, and **habituation to static reminders**. The app must never require the user to fill out a form to capture a task — one drag or one paste is the entire interaction.

**Platform:** macOS only, v1. **Distribution:** direct build / TestFlight-style, not App Store gated for v1 (App Sandbox compliance is a stretch goal, not a blocker).

**Assumed stack (DECISION MADE, see note):** Native Swift + SwiftUI, with AppKit bridging (`NSPanel`, `NSStatusItem`, `NSPasteboard`, `NSDataDetector`) where SwiftUI has no native primitive. No third-party dependencies for v1. Reasoning: the always-on-top / resizable / non-activating panel requirement and clipboard/drag introspection requirements are AppKit-level capabilities that a cross-platform framework (Electron/Tauri) would fight against, not gain from. If this assumption is wrong for your environment, stop and confirm before proceeding — do not silently switch stacks mid-build.

---

## 2. Problem statement (why each feature exists — do not skip this, it constrains implementation choices downstream)

| Problem (research-grounded) | Consequence if ignored | Feature that addresses it |
|---|---|---|
| Time is perceived as "now" vs. "not now"; internal clock is measurably miscalibrated | Users under- or over-estimate task duration by 40%+; deadlines feel unreal until they're already missed | Ambient shrinking-ring timer, always visible, not a bare digital number |
| Task initiation, not sustained focus, is the actual failure point | A 25-minute commitment feels too far away to start; user never begins | Default short timer intervals (5–15 min), instantly startable, extendable rather than shrinkable |
| Working memory drops uncaptured information within seconds | Links/ideas/screenshots are lost before they're filed "properly" | One-motion capture: drag or paste directly onto a task, zero mandatory fields |
| Reminder novelty wears off fast; static alerts get tuned out | User starts ignoring the app's notifications entirely within days | Escalating, varied-intensity reminder cues instead of one fixed alert style |
| Rigid schedules create shame-driven abandonment on low-energy days | User quits the whole app after one "failed" Pomodoro | All timer values are live-editable presets, never hardcoded, no guilt UI on skip/reset |
| Cluttered, multi-modal screens increase distractibility | The productivity tool itself becomes a distraction | Minimal, single-focus surfaces; animation is contained to state changes, not decoration |

---

## 2A. Deeper psychology/physiology → feature mapping (round 2 research)

This section documents a second, deeper research pass specifically into the **psychological and physiological mechanisms** behind ADHD reactions to situations (not just "time blindness" from §2), and translates each mechanism directly into a feature. Every feature added here is traceable to a specific mechanism — build agents should not treat these as generic "nice to have" additions; each closes a real, cited gap.

| Mechanism (research-grounded) | What it looks like in a real user | Feature added (FR ID) |
|---|---|---|
| **Rejection Sensitive Dysphoria (RSD) / emotional dysregulation.** Perceived criticism or failure triggers disproportionate shame/misery; people pre-emptively avoid tasks (not applying, not submitting) specifically to dodge the anticipated dysphoria of failing at them. | A missed timer, an overdue task, or a "you failed" style message doesn't just get ignored — it can trigger shutdown/avoidance of the *whole app*, not just the one task. | **FR-12: RSD-safe copy system** — a single source of truth for all user-facing strings around failure/lateness/skipping, enforced app-wide, never generated ad hoc per-view. |
| **Interest-based nervous system (Dodson's NICE/INCUP model).** Dopamine release for ADHD brains is gated by Novelty, Interest, Challenge/Competition, and Urgency — not by importance/consequence the way neurotypical motivation usually works. A task that's merely "important" can stay unstarted indefinitely; the same task reframed with any of N-I-C-U often gets started immediately. | The user has a boring-but-important task sitting untouched for days, while a "new and shiny" task gets done same-day. | **FR-13: Task framing assist** — a lightweight, optional per-task prompt that lets the user (or, later, the app) inject one NICE lever into a stale task: add a self-imposed deadline (urgency), tag it "quick win" (challenge/competition against self via streak), or mark it for the next focus session's first slot (novelty of "new session, new attempt"). |
| **Decision/choice paralysis.** With too many open options, ADHD executive function overload causes a freeze response — logically knowing what to do but being unable to pick and start. Documented as directly correlated with executive dysfunction scores and reduced life satisfaction. | Staring at a 15-item list and doing nothing, even though several items are trivial. | **FR-14: "What now" single-pick mode** — a one-tap surface that shows exactly ONE suggested next task (not a ranked list to evaluate), pulled from the day's uncompleted tasks by a simple, transparent rule (see DESIGN.md §11), with a single "show me a different one" escape hatch instead of a full list. |
| **Task initiation failure compounded by task *size/ambiguity*.** Paralysis is worse specifically when a task is underspecified or feels too large/complex to know where to even begin — the brain can't locate a first physical action. | "Write the report" sits untouched for a week; "open the doc and write one sentence" gets done in the moment. | **FR-15: Next Tiny Step decomposition** — an optional per-task action that lets the user (manually, no AI required for v1) attach a single "first physical action" sub-line to any task, shown ABOVE the task title when it's the active/focused task, so starting requires zero planning in the moment. |
| **Body doubling / social co-regulation.** Working near another (even passively present, non-interactive) person measurably increases task initiation and continuation, largely independent of any actual help being given — the mechanism is presence + implicit accountability + co-regulation, not supervision. | Someone who cannot start solo starts immediately in a library or on a coworking call, despite doing the identical task. | **FR-16: Solo "focus companion" presence cue** — see note below; a lightweight, local, non-networked stand-in for body doubling (v1 scope-limited, see note), building the surface for a real co-working/virtual-body-double feature later. |
| **Overstimulation as a distinct failure mode from under-stimulation.** ADHD paralysis research explicitly names overstimulation (too much sensory/choice input at once) as its own trigger, separate from boredom — meaning a "premium, glowing, attention-grabbing" UI executed carelessly can directly cause the exact shutdown this app is trying to prevent. | A visually busy app with many simultaneous animated elements makes the user close it rather than use it. | Reinforces the existing FR-9.2/FR-9.3 constraints — no new FR, but elevates them from "nice design principle" to "a documented failure-mode mitigation." Build agents must not treat FR-9's restraint as negotiable when adding future visual features. |

**Note on FR-16 scope (body doubling):** true body doubling (a live other human, virtual or in-person) is out of scope for a local, no-backend, no-accounts v1 app — it requires networking, presence/matching, and privacy handling that would blow up the "no third-party dependencies, single local app" constraint in DESIGN.md §15. FR-16 as specified for v1 is intentionally a **modest, honest placeholder**: an ambient, local "presence" visual (e.g., a subtle steady glow/breathing indicator on the timer while a focus session is active, representing "someone/something is here with you while you work") — not a simulated fake person, not a chatbot pretending to be a co-worker (which would be dishonest and could itself trigger RSD if it ever "reacts" to the user negatively). A real multi-user body-doubling feature (matching with another real user, or a scheduled co-working room) is explicitly flagged as a **v2 candidate**, not built now, because it requires backend/accounts infrastructure this PRD's v1 constraints exclude.

---

## 3. Users and usage context

- **Primary user:** an individual (student/professional) working at a Mac most of the day, who wants the tool present but not intrusive — hence menu-bar residency, not a dock app they have to alt-tab to.
- **Usage pattern:** glancing interaction, not sustained interaction. The user should be able to add a task, start a timer, or check remaining time in under 2 seconds without breaking their current app's focus.
- **Non-goal:** this is not a full project-management tool, not a calendar replacement, not a team collaboration tool. No multi-user, no cloud sync in v1 (local storage only — see DESIGN.md §Data Layer).

---

## 4. Functional requirements

Each requirement has an ID (used in DESIGN.md and should be used in commit messages / task tracking during build). Each has explicit acceptance criteria — treat these as the test spec.

### FR-1: Menu bar residency
- **FR-1.1** App runs as a menu bar (`NSStatusItem`) app. It must NOT show a Dock icon by default (`LSUIElement = true` in Info.plist).
- **FR-1.2** Clicking the menu bar icon toggles the main floating panel (open if closed, close if open — unless pinned, see FR-3).
- **FR-1.3** The menu bar icon itself visually reflects current app state (idle / focus-running / break-running / reminder-pending). Exact visual states defined in DESIGN.md §Menu Bar Icon States.
- **Acceptance:** Icon is visible at all times the app runs; icon appearance changes within 1 frame of a state change; clicking toggles the panel with no dock icon ever appearing.

### FR-2: Floating panel window (the main UI surface)
- **FR-2.1** The main UI lives in a **non-activating floating panel**, not a normal window and not a menu-bar popover. It must not steal keyboard focus from whatever app the user is working in unless the user clicks into a text field inside it.
- **FR-2.2** Panel is resizable by dragging any edge/corner, with a sane minimum size (defined in DESIGN.md).
- **FR-2.3** Panel is draggable by its background (click-and-drag anywhere non-interactive to move it).
- **FR-2.4** Panel remembers its last position and size across app relaunches.
- **Acceptance:** Panel can be resized smaller/larger without layout breakage (see FR-8 for responsive behavior); dragging it does not click through to whatever's underneath; reopening the app restores the last frame.

### FR-3: Pin / always-on-top
- **FR-3.1** A pin toggle (icon button, always visible in the panel's own chrome) sets the panel to stay above ALL other application windows, including full-screen apps, and to remain visible across macOS Spaces/desktops.
- **FR-3.2** When unpinned, panel behaves like a normal floating window (still non-activating, but not forced above full-screen apps).
- **FR-3.3** Pin state persists across relaunches.
- **Acceptance:** With another app in full-screen mode, pinning the panel makes it visible on top of that full-screen app; switching Spaces keeps a pinned panel visible; unpinning returns normal window layering.

### FR-4: Todo list — core CRUD
- **FR-4.1** User can add a task via: (a) typing into a persistent "quick add" field always present at the top of the panel, (b) dragging content onto the list, (c) pasting content while the list is focused.
- **FR-4.2** Each task has: title (required, auto-derived from pasted content if not typed), an optional list of attachments (links/images), an optional due date/time, a completion state, and a creation timestamp.
- **FR-4.3** Tasks can be marked complete (single click/tap on a checkbox), edited inline (click text to edit), reordered by drag, and deleted (swipe or explicit delete affordance).
- **FR-4.4** Completing a task triggers the completion micro-animation (see FR-7) — this is not optional, it is core to the product's purpose (per §2).
- **Acceptance:** All CRUD operations complete in a single user action each (no confirmation dialogs for add/edit/reorder; a lightweight undo affordance is acceptable in place of a delete confirmation).

### FR-5: Auto-classifying capture
- **FR-5.1** When a user pastes or drops content onto a task (existing or the quick-add field), the app inspects it and classifies automatically:
  - Plain URL or text containing a URL → rendered as a link chip with fetched page title (best-effort; fall back to raw URL string if fetch fails or is offline) and favicon.
  - Image data (from clipboard or file drag) → attached as a thumbnail on the task.
  - Natural-language date/time expressions in typed or pasted text (e.g. "tomorrow 5pm", "in 2 hours", "Friday") → parsed and auto-populate the task's due date/time field. The date text itself is removed from the visible title once parsed (so the title doesn't read "buy milk tomorrow 5pm" AND show a due date badge — pick one representation; DESIGN.md specifies which).
  - Plain text with none of the above → becomes the task title verbatim.
- **FR-5.2** If multiple content types are pasted at once (e.g., a link and a date in the same paste), classify all of them onto the same task.
- **FR-5.3** Classification must never block or require user confirmation — it happens immediately and silently. If classification is wrong, the user can remove/edit the attachment or due date manually (this is an escape hatch, not a confirmation step).
- **Acceptance:** Pasting a bare URL onto a task produces a link chip within 2 seconds (network-dependent for title fetch, but the chip itself with raw URL appears instantly); dropping a screenshot produces a thumbnail instantly; typing "call mom tomorrow 6pm" produces a task titled "call mom" with a due badge showing tomorrow 6pm.

### FR-6: Pomodoro-style timer system
- **FR-6.1** Timer has two states: Focus and Break, alternating.
- **FR-6.2** Default presets ship as: **Low energy (10 min focus / 5 min break)**, **Normal (20 min focus / 5 min break)**, **Deep work (45 min focus / 10 min break)**. These are DEFAULTS, not fixed values — see FR-6.4.
- **FR-6.3** Timer is represented visually as an ambient shrinking/filling ring or disc (see DESIGN.md §Timer Visual Spec), NOT primarily as a digital number. A digital number may be shown as a secondary/small label, never as the primary representation.
- **FR-6.4** ALL interval lengths (focus duration, break duration, long-break-after-N-cycles) must be user-editable at any time, including mid-session (a change takes effect on the next cycle boundary, not retroactively truncating a running session).
- **FR-6.5** Starting a timer can optionally be linked to a specific task (shows the task title alongside the timer) or run standalone.
- **FR-6.6** User can pause, resume, skip, or reset a running timer at any time with a single action. No confirmation dialogs. No shame-coded copy (never say things like "you gave up" — neutral language only, e.g. "Reset").
- **FR-6.7** After every 4 focus cycles, a "long break" is suggested (length also user-editable), matching the traditional Pomodoro long-break pattern — but this is a suggestion the user can dismiss, not an enforced state.
- **Acceptance:** Changing a preset's duration mid-session does not cut the current cycle short; pausing/resuming preserves elapsed time exactly; the ring visual updates smoothly (no visible stepping/jank) as time elapses.

### FR-7: Reminder / attention system
- **FR-7.1** When a focus or break cycle ends, the app must notify the user WITHOUT relying on the panel being visible or focused.
- **FR-7.2** Notification is escalating and capped, not repeating indefinitely:
  1. Stage 1 (immediate): menu bar icon shifts to its "reminder-pending" visual state (color/glow change + subtle pulse animation).
  2. Stage 2 (after a short delay if unacknowledged, default 30s, user-configurable): a native macOS notification banner is posted (using `UserNotifications` framework) with the cycle result (e.g. "Focus session done — take a break") and quick actions (Start Break / Snooze / Dismiss) inline in the notification if the OS supports it.
  3. There is no Stage 3. The app must never force a full-screen takeover or an unclosable modal. This is intentional per §2 (overstimulation/forced-interrupt backfire risk).
- **FR-7.3** Every reminder is snoozable with a single action (default snooze length user-configurable, e.g. 5 min).
- **FR-7.4** The visual/audio treatment of Stage 1 varies across occurrences (e.g. rotate between a small set of glow-color/pulse-pattern variants) rather than being pixel-identical every time, to reduce habituation — see DESIGN.md §Reminder Variants for the exact variant set to implement.
- **Acceptance:** With the panel closed and another app frontmost, finishing a focus cycle produces a menu bar state change immediately and a native notification within the configured delay if not acknowledged; snoozing resets the escalation timer; no reminder ever blocks input to other apps.

### FR-8: Responsive / resizable layout
- **FR-8.1** All panel content (task list, timer, quick-add field) must reflow sensibly at both the minimum panel size and a much larger user-resized size — no fixed pixel-width assumptions in layout.
- **Acceptance:** Resizing the panel from minimum to 2x width/height produces no clipped text, no overlapping elements, no fixed-size dead space that fails to use the extra room (list area should expand to fill available space).

### FR-9: Visual design system ("premium" requirement)
- **FR-9.1** The app uses a cohesive dark-first visual theme (see DESIGN.md §Visual Language for exact palette, spacing, typography) with glow and ripple-style micro-animations applied specifically to: (a) menu bar icon state changes, (b) task completion, (c) timer cycle transitions, (d) the pin toggle when engaged.
- **FR-9.2** Animation is state-driven and functional (it communicates something happened), never purely decorative and never continuous/looping in a way that competes for attention while the user is trying to work (e.g., no idle ambient animation on the task list itself while nothing is happening).
- **FR-9.3** A "stimulation intensity" setting (Gentle / Standard / High) scales the amplitude and presence of all of the above animations plus notification sound — see FR-10.
- **Acceptance:** With intensity set to Gentle, all animations still occur but are visibly subtler (lower opacity/scale delta, no sound); with High, animations and an optional sound are more pronounced. No intensity setting removes functional feedback entirely (there is always SOME acknowledgement of state change).

### FR-10: Settings
- **FR-10.1** A settings surface (can be a simple tab/section within the panel, does not need a separate window) exposes: timer presets (add/edit/delete), reminder escalation delay, snooze length, stimulation intensity (FR-9.3), daily task cap toggle (FR-11), and pin-panel default state on launch.
- **Acceptance:** All settings persist across relaunch (see DESIGN.md §Data Layer).

### FR-11: Daily scope cap (optional, user-toggleable)
- **FR-11.1** An optional mode (off by default, enabled in Settings) implements a "1-3-5" style cap: the active/visible list for "today" is limited to 1 big + 3 medium + 5 small tasks; anything beyond that is visually deprioritized into a collapsed "later" section rather than hidden/blocked.
- **FR-11.2** Task "size" (big/medium/small) is a simple manual 3-way tag the user sets per task, not auto-computed.
- **Acceptance:** With the cap enabled and the day's 1-3-5 slots full, additional tasks are still addable but appear in the collapsed section, not blocking task creation.

### FR-12: RSD-safe copy system
- **FR-12.1** All user-facing strings related to lateness, skipped sessions, incomplete tasks, resets, or "failure" states live in a single strings file/module (see DESIGN.md §12), never inline-authored per view. This is a hard rule so a build agent can't accidentally write shame-coded copy in one screen while getting it right elsewhere.
- **FR-12.2** Tone rules for that file: neutral or encouraging framing only; never implies the user personally failed, gave up, or should feel bad. Compare: NOT "You missed your focus session" → INSTEAD "That session didn't happen — want to try a shorter one?" NOT "3 tasks overdue" as a red alarming badge → INSTEAD a neutral-colored count with no shame-adjacent color (no red/exclamation iconography for overdue items — use a neutral badge color from the palette in DESIGN.md §9, not an alert color).
- **FR-12.3** No streak-loss guilt messaging. If a streak breaks, the app either says nothing about it or frames it neutrally ("Starting a new streak today") — never "You lost your streak."
- **Acceptance:** grep-style audit of all user-facing strings against the module in FR-12.1 finds zero inline failure/lateness strings elsewhere in the codebase; no overdue/reset/skip UI uses red or an alarm icon.

### FR-13: Task framing assist (interest-based nervous system lever)
- **FR-13.1** Any task, at any time, can have ONE optional "framing" attached by the user via a small menu: **Self-deadline** (urgency lever — sets/edits `dueDate`), **Quick win** (challenge lever — tags the task so it surfaces first in "What now" mode, FR-14), or **Do first next session** (novelty lever — pins it to the top of the next timer session's linked-task suggestion).
- **FR-13.2** This is manual and user-initiated only for v1 — the app does not automatically decide a task is "stale" or auto-apply a framing. No behavioral-nudge dark patterns; the user is choosing a lever for themselves, not being pushed.
- **Acceptance:** applying any one framing is a single tap/action from the task row's existing context menu; a framed task visibly reflects its framing (small icon/badge) without needing to reopen a detail view.

### FR-14: "What now" single-pick mode
- **FR-14.1** A single button/surface (accessible from the panel's main view, not buried in settings) that, when triggered, shows exactly ONE task as "do this next" — not a filtered list, not a ranked top-5. A single "different one" affordance re-rolls the pick.
- **FR-14.2** Selection rule (deterministic, documented in DESIGN.md §11, not a black box): prioritize any task tagged "Quick win" (FR-13.1) due today or overdue; if none, prioritize the smallest-sized task (FR-11's size tag) due today; if none tagged, pick the oldest uncompleted task by `createdAt`. This must be simple enough that the user can predict/trust it — no opaque ranking model.
- **Acceptance:** triggering "What now" always yields exactly one task with no list visible underneath it; re-rolling never repeats the immediately-previous suggestion if more than one candidate exists.

### FR-15: Next Tiny Step decomposition
- **FR-15.1** Any task can have one optional short text field — "first step" — editable inline, distinct from the task title.
- **FR-15.2** When a task is the currently linked/active task in a running timer session (FR-6.5), its "first step" text (if present) is shown prominently above the task title in `TimerView`, not just inside the task row.
- **FR-15.3** This field is plain user-entered text for v1 — no AI-generated step suggestions (that's an explicit v2 idea, not in scope here; do not add an AI call for this).
- **Acceptance:** a task with a "first step" set shows that text in both the task row and, when active, the timer view; a task without one shows nothing extra (no empty placeholder clutter).

### FR-16: Focus companion presence cue (v1-scoped body-doubling stand-in)
- **FR-16.1** While a focus session is running, `TimerView` displays a subtle, steady ambient indicator (see DESIGN.md §14 "presence glow") distinct from the timer ring itself, representing passive companionship — NOT a character, avatar, or chat agent, and it never comments on the user's behavior or performance (per the honesty note in §2A — a fake reactive presence would risk triggering RSD if it ever reads as judgmental).
- **FR-16.2** This is visual/ambient only for v1 — no audio, no text messages from the "companion," no personality. It's a presence cue, not a feature with its own UI surface.
- **Acceptance:** the presence cue is visible only during an active focus session (not idle, not during breaks), never produces any text output, and its visual treatment is the steady "presence glow" defined in DESIGN.md, distinct from the reminder-pulse glow (FR-7) so the two are never confused.

---

## 5. Explicit non-goals for v1

- No cloud sync / multi-device — local storage only.
- No team/sharing features.
- No mobile companion app.
- No AI-based task breakdown or auto-prioritization (may be a v2 idea, out of scope now).
- No App Store sandboxing hardening (functional correctness first).
- No calendar (Google/Outlook) integration.
- No real multi-user body doubling (live matching with another human, scheduled co-working rooms) — v2 candidate per §2A note on FR-16; v1 ships only the local ambient presence-cue stand-in.
- No AI-generated task decomposition/step suggestions — FR-15 is manual-entry only in v1.
- No automatic/algorithmic detection of "stale" tasks to auto-apply framing (FR-13) — user-initiated only, to avoid dark-pattern-style nudging.

---

## 6. Phase-wise build plan (sequential, gated)

> Each phase must be fully working and manually verifiable against its acceptance criteria before starting the next. Do not parallelize phases. Do not add features from a later phase early "while you're in there."

### Phase 0 — Project scaffold
- Create the Xcode project (SwiftUI App lifecycle), set `LSUIElement = true`, confirm app launches with zero Dock icon and zero visible window.
- Set up the folder/file structure exactly as specified in `DESIGN.md §Project Structure`.
- **Exit criteria:** app builds and runs, shows nothing but is running (verifiable in Activity Monitor), no crash.

### Phase 1 — Menu bar + floating panel skeleton (FR-1, FR-2, FR-3)
- Implement `NSStatusItem` menu bar icon (static single state icon is fine for this phase).
- Implement the `NSPanel` subclass per DESIGN.md exact config, hosting an empty SwiftUI view.
- Wire click-to-toggle, resizing, dragging, position/size persistence, and the pin toggle with true always-on-top/all-Spaces behavior.
- **Exit criteria:** all of FR-1, FR-2, FR-3 acceptance criteria pass with a placeholder empty panel.

### Phase 2 — Todo list core (FR-4, FR-8)
- Build the task data model, local persistence, and the SwiftUI list UI: add, complete, edit, reorder, delete.
- Build the quick-add field.
- Ensure responsive layout at min/max panel sizes.
- **Exit criteria:** FR-4 and FR-8 acceptance criteria pass. No auto-classification yet — plain text tasks only.

### Phase 3 — Auto-classifying capture (FR-5)
- Implement `NSDataDetector`-based date/URL parsing and `NSPasteboard`/drag-and-drop image handling.
- Wire classification into the add/edit flow from Phase 2.
- **Exit criteria:** FR-5 acceptance criteria pass for all three content types plus the mixed-content case.

### Phase 4 — Timer system (FR-6)
- Build the timer engine (state machine: focus/break/long-break, pause/resume/skip/reset), the preset data model, and the ring/disc visual.
- Link timer to menu bar icon state (still static color swap is fine here; full animation comes in Phase 6).
- **Exit criteria:** FR-6 acceptance criteria pass, including mid-session preset edits.

### Phase 5 — Reminder/notification system (FR-7)
- Implement the two-stage escalation (menu bar state + `UserNotifications` banner), snooze, and variant rotation.
- **Exit criteria:** FR-7 acceptance criteria pass with the app backgrounded and another app frontmost/full-screen.

### Phase 6 — Visual polish pass (FR-9)
- Implement the full glow/ripple animation set per DESIGN.md §Visual Language and §Animation Specs, wired to all the state changes identified in FR-9.1.
- Implement the stimulation-intensity setting and confirm it scales all animation/sound correctly.
- **Exit criteria:** FR-9 acceptance criteria pass at all three intensity levels.

### Phase 7 — Settings + daily cap (FR-10, FR-11)
- Build the settings surface, wire every setting to persistence and to the systems built in Phases 1–6.
- Implement the optional 1-3-5 daily cap mode.
- **Exit criteria:** FR-10 and FR-11 acceptance criteria pass.

### Phase 8 — Psychology-driven feature set (FR-12, FR-13, FR-14, FR-15, FR-16)
- **Do FR-12 first and treat it as a gate, not just another item** — build the centralized RSD-safe strings module, then retrofit every existing string written in Phases 1–7 that touches lateness/skip/reset/overdue language to pull from it. This is the one place in the whole plan where an earlier phase's output gets revisited; that's intentional.
- Implement FR-13 (task framing menu), FR-14 ("What now" single-pick), FR-15 (Next Tiny Step field + TimerView surfacing), and FR-16 (presence glow cue) in that order — each is additive and independently testable against the task/timer systems already built.
- **Exit criteria:** FR-12 through FR-16 acceptance criteria all pass; a string audit (per FR-12's acceptance criterion) finds no non-compliant copy anywhere in the app, including screens built in earlier phases.

### Phase 9 — Full regression pass
- Re-verify every acceptance criterion in this document end-to-end, in one continuous session, including relaunching the app mid-way to check all persistence.
- **Exit criteria:** every FR in §4 passes with no regressions from earlier phases.

---

## 7. Open decisions requiring human sign-off before/while building

- **DECISION NEEDED:** Local persistence mechanism — DESIGN.md defaults to a simple JSON-on-disk store for v1 simplicity (see DESIGN.md §Data Layer) rather than SwiftData/CoreData, to keep the build simple for a lower-capability build agent. Confirm this is acceptable, or explicitly request SwiftData if you want cleaner future migration.
- **DECISION NEEDED:** Minimum macOS version target. DESIGN.md assumes macOS 14+ (Sonoma) to get modern SwiftUI APIs. Lower this only if you need to support older Macs, which will require AppKit fallbacks for some SwiftUI-only APIs referenced in DESIGN.md.
- **DECISION NEEDED:** App name/bundle identifier/icon — placeholder "Focus" used throughout; replace before Phase 0 scaffold if you have a real name chosen.
