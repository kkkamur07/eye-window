# Eye Window — Product Requirements Document

## Problem Statement

Working across two monitors means constantly hunting through Command+Tab to move keyboard focus between displays — for example, a video course on one screen and notes on another. On a single display, the same friction appears when juggling two or three apps (Obsidian, Safari, Terminal): one **Last-focused app** per **Display** is not enough.

Separately, hours of continuous screen use without structured breaks is hard on the eyes. Wall-clock timers do not reflect actual computer use. The user needs **Blink reminders** tied to **Active usage time**, with at-a-glance **Menu bar progress** so they know how much active time has accumulated and how long until the next **Blink time** — without opening a detailed settings panel.

## Solution

Eye Window is a native macOS menu bar utility with two capabilities:

1. **Display focus** — With exactly two **Displays**, **Display switch chord** **⌘⌥1** / **⌘⌥2** moves keyboard **Focus target** to the top of that **Display**'s **Focus stack**. Repeated chord while already on that **Display** **Rotate**s to the next app in the stack. Manual focus changes build the stack; quit apps are pruned eagerly. Hotkey-only — no stack list in the menu.

2. **Blink reminders** — Tracks **Active usage time** from input; shows **Blink time overlay** after the **Eye break interval**; **Menu bar progress** in the icon (`D1 · 12/60`) and full **Blink status** with elapsed and remaining times in the menu dropdown.

No webcam, cloud, or ML. Local-only, menu-bar simple.

## User Stories

### Display focus — baseline (implemented)

1. As a dual-monitor user, I want to press **⌘⌥1** or **⌘⌥2** to focus the top app on that **Display**'s **Focus stack**, so that I avoid Command+Tab when switching between course and notes.

2. As a dual-monitor user, I want manual clicks and Command+Tab to update **Focus stack** membership per **Display**, so that hotkeys reflect what I actually use.

3. As a dual-monitor user, I want **Display** numbers to match macOS left-to-right numbering, so that 1 and 2 match System Settings.

4. As a dual-monitor user with zero, one, or three+ **Displays**, I want switching disabled and a clear menu warning, so that I am not surprised.

5. As a dual-monitor user, I want **Accessibility permission** prompted when needed, so that apps can be activated.

6. As a dual-monitor user, I want the menu bar icon to show which **Display** has focus and the active app name, so that I can trust hotkey switches.

7. As a dual-monitor user, I want hotkeys and focus tracking active as soon as the app launches, so that I do not need to open the menu first.

8. As a dual-monitor user, I want **Display switch chord** to use Command+Option+number (not Command alone), so that browser tab shortcuts like Arc **⌘1** do not conflict.

9. As a dual-monitor user, I want **Focus stack** remembered only for the current run, not across reboots, so that stale apps are not resurrected.

10. As a dual-monitor user, I want a sensible fallback when no app is on a **Display**'s **Focus stack** yet, so that the first hotkey press still focuses something usable on that screen.

### Display focus — Focus stack and Rotate (to build)

11. As a dual-monitor user with two or three apps on one **Display**, I want repeated **⌘⌥N** while already on that **Display** to **Rotate** through every app on its **Focus stack**, so that I cycle apps without Cmd+Tab.

12. As a dual-monitor user, I want the first **⌘⌥N** after being on the other **Display** to land on the top of the **Focus stack** (not rotate), so that switching displays and cycling apps are distinct gestures.

13. As a dual-monitor user, I want **Rotate** to wrap from the bottom of the **Focus stack** back to the top, so that cycling is continuous.

14. As a dual-monitor user, I want re-focusing an app to move it to the top of the **Focus stack**, so that my most recent app is what I get on a cross-display switch.

15. As a dual-monitor user, I want quit apps removed from the **Focus stack** immediately, so that **Rotate** never targets dead apps.

16. As a dual-monitor user, I want **Rotate** to be a no-op when only one app is on the **Focus stack**, so that repeated chords do not cause surprise jumps.

17. As a dual-monitor user, I want display focus driven entirely by hotkeys with no **Focus stack** list in the menu, so that the menu stays minimal and I build muscle memory.

18. As a dual-monitor user, I want **Rotate** to log which app was activated, so that I can debug order in the menu log lines.

19. As a maintainer, I want **Focus stack** logic testable in **DisplayFocusSelfCheck** without Accessibility, so that stack order, dedupe, prune, and rotate index are verified automatically.

### Blink reminders — baseline (implemented)

20. As a screen-heavy user, I want **Active usage time** to accumulate only while I am typing, clicking, or scrolling, so that reminders reflect real desk time.

21. As a screen-heavy user, I want **Active usage time** to stop accumulating after **Idle threshold** (five minutes without input), so that a coffee break does not count toward the next **Eye break**.

22. As a screen-heavy user, I want **Active usage time** to resume when I return and use the computer again, so that tracking continues naturally after **Idle period**.

23. As a screen-heavy user, I want the next **Blink time** after sixty minutes of **Active usage time** by default, so that reminders match sustained use rather than clock time.

24. As a screen-heavy user, I want **Blink reminders** on by default at launch, with a menu toggle to pause, so that eye health is automatic but controllable.

25. As a screen-heavy user, I want a **Blink time overlay** on every **Display** with **Skip** confirmation, so that breaks are unavoidable but not dismissible by accident.

26. As a screen-heavy user, I want to pick a shorter **Eye break interval** from the menu for testing, so that I can verify overlays without waiting an hour.

27. As a screen-heavy user, I want my **Eye break interval** choice saved between launches, so that test presets persist during development.

28. As a screen-heavy user, I want **Active usage time** not to accumulate during a **Blink time overlay**, so that overlay time does not double-count.

29. As a screen-heavy user, I want **Blink reminders** to work on any display count, so that eye health applies on laptop-only setups too.

### Blink reminders — Menu bar progress (to build)

30. As a screen-heavy user, I want the menu dropdown to show **Blink status**, elapsed **Active usage time**, and time until the next **Blink time** together, so that I see full progress at a glance.

31. As a screen-heavy user, I want the menu bar icon to show **Menu bar progress** as a fraction (e.g. `D1 · 12/60`) next to display focus, so that I see blink progress without opening the menu.

32. As a screen-heavy user, I want **Menu bar progress** to use the current **Eye break interval** including test presets, so that `12/30` is correct when I pick thirty seconds for testing.

33. As a screen-heavy user, I want the progress fraction frozen when **Blink reminders** are paused or in an **Idle period**, so that I can see accumulated progress stalled without it ticking down falsely.

34. As a screen-heavy user, I want sub-minute remaining times shown as seconds in the dropdown when using short test intervals, so that countdown is readable near a break.

35. As a screen-heavy user, I want paused **Blink status** clearly labeled in the dropdown, so that I know reminders are off without guessing from a frozen fraction.

### Cross-cutting

36. As a user, I want all processing local on my Mac with no network calls, so that privacy is preserved.

37. As a user, I want the app to stay a lightweight menu bar utility, so that it stays out of the way.

38. As a maintainer, I want domain terms in CONTEXT.md aligned with this PRD, so that future work shares one vocabulary.

39. As a maintainer, I want post-MVP items (window-level focus, third-display switching, cross-session persistence, slot-based hotkeys) deferred, so that scope does not creep.

## Implementation Decisions

### Guiding principle

Prefer pure logic in **DisplayFocusCore** and thin AppKit wiring in **DisplayFocus**. Hotkey-driven UX; menu shows status and blink progress, not **Focus stack** lists.

### Already implemented

| Area | Status |
|------|--------|
| **Dual-display mode**, **Display switch chord**, single **Last-focused app** per display | Done |
| **FocusHistory**, **FocusController**, **FocusObserver**, Accessibility activation | Done |
| **Blink reminders** full pipeline: **ActiveUsageTracker**, input monitor, tick loop, overlay, skip, pause | Done (issues 016–020) |
| Menu **Break interval** presets with UserDefaults persistence | Done |
| Menu blink line (status + time until break only; no elapsed; icon focus-only) | Partial — superseded by **Menu bar progress** slice |

### To build — Menu bar progress (issue 021)

| Module | Responsibility |
|--------|----------------|
| **SessionCoordinator** | Already publishes `blinkAccumulatedSeconds`, `blinkSecondsUntilBreak`, `blinkBreakInterval`, `blinkIsIdle`, `blinkRemindersPaused` — consume for display formatting only. |
| **Menu bar icon title** | Combine display focus with **Menu bar progress**: e.g. `Display Focus · D1 · Obsidian · 12/60` or compact `D1 · 12/60` if space tight. |
| **Menu dropdown** | Replace single-line blink status with **Blink status** + elapsed + remaining: e.g. `Active: 12m · Break in: 48m`; prefix `idle` or `paused` when applicable; fraction frozen per CONTEXT.md. |

**Formatting rules**

- Progress fraction: `floor(activeMinutes) / floor(intervalMinutes)` or equivalent using accumulated seconds vs **Eye break interval**; use minutes for display when interval ≥ 60 s.
- Icon shows fraction frozen when idle or paused.

### To build — Focus stack and Rotate (issues 022–023)

| Module | Responsibility |
|--------|----------------|
| **FocusHistory** (extend) | Per-**Display** ordered stack of **AppRef**; dedupe on record (move to top); `stack(display)`, `lastFocused`, `nextForRotate(display, currentApp)`, `remove(app)`, `pruneTerminated()`. |
| **FocusController** | On activate: if target **Display** equals current keyboard **Display** and stack has >1 app, activate **Rotate** target instead of top only. |
| **AppModel / hotkey path** | Pass current focused app and display into activation decision. |
| **App termination observer** | On app quit, remove from all **Focus stacks** (eager prune). |

**Rotate decision (pure core)**

```
on Display switch chord for display D:
  if currentFocusDisplay == D and stack(D).count > 1:
    activate next app in stack after current (wrap)
  else:
    activate top of stack(D)  // existing behavior
  if stack(D).count == 1 and currentFocusDisplay == D:
    no-op
```

**Constants**

- Stack depth: unlimited session apps per **Display** (typically 2–3 in practice).
- No menu list of stack apps.

### Permissions

Unchanged: **Accessibility** for activation; **Input Monitoring** may be required for blink input tracking.

### Interaction between subsystems

- **Menu bar progress** and **Rotate** are independent; both share icon title space — prioritize compact fraction alongside **Display** indicator.
- **Blink time overlay** blocks input; does not affect **Focus stack**.

## Testing Decisions

**Good tests**: Observable inputs/outputs at module boundaries; no real Accessibility or overlay windows in unit tests.

| Module | Test approach |
|--------|----------------|
| **FocusHistory** / **Focus stack** | **DisplayFocusSelfCheck**: record order, dedupe move-to-top, remove on prune, `nextForRotate` wrap, single-app no-op index, empty stack. |
| **ActiveUsageTracker** | Existing self-check; unchanged. |
| **Menu bar progress** | Manual: icon shows `D1 · 12/60`; dropdown shows elapsed + remaining; frozen when idle/paused; updates with **Break interval** preset change. |
| **Rotate** | Manual on dual-display hardware: cross-display → top; same display repeat → cycle; quit app → skipped on rotate. |

**Seams (highest first)**

1. **FocusHistory** stack + rotate index — **DisplayFocusSelfCheck** (new).
2. **Menu bar formatting** — manual via menu and icon (data already on **SessionCoordinator**).
3. **Rotate** end-to-end — manual hotkey on hardware with Accessibility.

Prior art: **DisplayFocusSelfCheck** for **FocusHistory** (single-app), **ActiveUsageTracker** (016).

## Out of Scope

- **Focus stack** list or clickable apps in the menu
- Slot-based hotkeys (**⌘⌥⇧N**) — **Rotate** only
- Window-level or region-level focus
- Third+ **Display** switching (warn/disable; overlays still cover all screens)
- Webcam, gaze, ML, cloud
- Persisting **Focus stack** or **Active usage time** across restarts
- User-configurable **Idle threshold** or **Overlay duration** in UI ( **Eye break interval** presets in menu are in scope and done)

## Further Notes

- Domain glossary: `CONTEXT.md` (includes **Focus stack**, **Rotate**, **Menu bar progress**, **Blink status**).
- Blink baseline delivered in issues `016`–`020`.
- New work: issues `021`–`023`.
- Implementation order: `021` (menu progress) then `022` → `023` (**Focus stack** then **Rotate**); `021` and `022` can run in parallel.
