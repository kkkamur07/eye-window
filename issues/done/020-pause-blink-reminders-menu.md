---
id: "020"
title: "pause-blink-reminders-menu"
type: AFK
status: done
blocked_by:
  - "017-input-monitor-and-tick-loop.md"
parent_prd: "issues/prd.md"
---

## Parent

`issues/prd.md` — **Blink reminders** pause toggle.

## What to build

Add a menu bar toggle “Pause blink reminders” (or equivalent). Default: **Blink reminders** active (not paused). When paused, call **ActiveUsageTracker** `setPaused` so **Active usage time** does not accumulate and **triggerBreak** never fires. Menu reflects paused vs active state clearly.

Resuming from pause continues from current accumulated time (do not reset on unpause). If an overlay is showing, pause toggle behavior should either be disabled or documented — prefer disabling pause toggle while overlay is active.

## Acceptance criteria

- [ ] Toggle appears in menu bar menu; default off (reminders running)
- [ ] Paused: no accumulation, no **triggerBreak**, menu shows paused status
- [ ] Unpaused: tracking resumes from prior accumulated time
- [ ] Display focus hotkeys unaffected while paused
- [ ] Manual: pause during active use, confirm countdown frozen; unpause, confirm tracking resumes

## Blocked by

- `issues/017-input-monitor-and-tick-loop.md`

## User stories addressed

- User story 20
- User story 21
- User story 22
- User story 23
