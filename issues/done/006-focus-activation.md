---
id: "006"
title: "focus-activation"
type: AFK
status: done
blocked_by:
  - "002-dual-display-gating.md"
  - "004-focus-history.md"
  - "001-menu-bar-session.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **FocusController**, **FocusObserver**; **Focus fallback**.

## What to build

With Accessibility granted: **FocusObserver** records focus changes into **FocusHistory** (clicks, Command+Tab, any system focus change). **FocusController** activates last-focused app on a display, or **Focus fallback** (frontmost on that display) when none known. Callable from coordinator/tests in dual mode only; no gaze loop required for manual verification via menu debug action or unit integration stub.

## Acceptance criteria

- [x] Accessibility permission requested when activating; blocked state if denied
- [x] Manual focus change on display 2 updates `FocusHistory` for display 2
- [x] `activate(display: 2)` with known last-focused switches to that app
- [x] `activate(display: 1)` with empty history uses frontmost on display 1
- [x] No activation attempted when `NotDual`
- [ ] Manual: two displays, click Obsidian on display 2, trigger activation for 2 → Obsidian focused

## Blocked by

- `issues/002-dual-display-gating.md`
- `issues/004-focus-history.md`
- `issues/001-menu-bar-session.md`

## User stories addressed

- User story 2
- User story 13
- User story 14
- User story 20 (accessibility portion)
