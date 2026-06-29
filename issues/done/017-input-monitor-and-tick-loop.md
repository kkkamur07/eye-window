---
id: "017"
title: "input-monitor-and-tick-loop"
type: AFK
status: done
blocked_by:
  - "016-active-usage-core-selfcheck.md"
parent_prd: "issues/prd.md"
---

## Parent

`issues/prd.md` — **InputMonitor**, **BlinkReminderCoordinator**, **SessionCoordinator** blink state.

## What to build

Wire **Blink reminders** into the running app without overlays yet. Monitor global keyboard, mouse, and scroll input; on each event call **ActiveUsageTracker** `recordActivity`. Run a ~1 s timer that calls `tick` and updates shared state.

Extend **SessionCoordinator** (or equivalent) with published blink fields: **Active usage time** accumulated, seconds until next **Blink time**, whether user is in **Idle period**, whether **Blink reminders** are paused, and whether a break was triggered (for the next slice to consume).

Show blink status in the menu bar menu (e.g. “Blink reminders: active · 42m until break” or “paused” / “idle”). Log **triggerBreak** when fired; do not show overlay in this slice — logging or a debug flag is enough to verify the effect fires.

**Blink reminders** are on by default at launch.

## Acceptance criteria

- [ ] Typing, clicking, or scrolling updates **Active usage time** (visible in menu or logs within a few seconds)
- [ ] No input for **Idle threshold** stops accumulation (menu reflects idle / frozen countdown)
- [ ] `tick` runs periodically while app is running
- [ ] When test-shortened interval is NOT used in production, countdown reflects sixty-minute **Eye break interval** semantics
- [ ] **triggerBreak** is emitted and observable (log line or coordinator flag) when interval reached; no overlay yet
- [ ] Display focus hotkeys and menu continue to work unchanged
- [ ] Manual: launch app, use computer briefly, confirm countdown moves; stop input 5+ min, confirm stall

## Blocked by

- `issues/016-active-usage-core-selfcheck.md`

## User stories addressed

- User story 16
- User story 17
- User story 18
- User story 19
- User story 20
- User story 23
- User story 24
- User story 33
