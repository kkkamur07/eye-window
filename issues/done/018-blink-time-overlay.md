---
id: "018"
title: "blink-time-overlay"
type: AFK
status: done
blocked_by:
  - "017-input-monitor-and-tick-loop.md"
parent_prd: "issues/prd.md"
---

## Parent

`issues/prd.md` — **Blink time overlay**, **Overlay message**, **Overlay duration**.

## What to build

When **BlinkReminderCoordinator** receives **triggerBreak**, present a **Blink time overlay** on every connected **Display**: full black, borderless, above normal windows, blocks interaction. Center the canonical **Overlay message** from CONTEXT.md.

Start a **Overlay duration** timer (forty-five seconds). When it elapses, dismiss all overlay windows and call **ActiveUsageTracker** `completeBreak` so **Active usage time** resets to zero toward the next **Eye break interval**.

While overlay is active, `tick` must pass `overlayActive: true` so usage does not accumulate during **Blink time**.

## Acceptance criteria

- [ ] **triggerBreak** shows simultaneous full-screen black overlays on all **Displays**
- [ ] **Overlay message** matches CONTEXT.md exactly
- [ ] Overlays block mouse and keyboard to underlying apps for **Overlay duration**
- [ ] After forty-five seconds overlays dismiss automatically
- [ ] **Active usage time** resets to zero after natural overlay completion
- [ ] Menu blink countdown restarts from full **Eye break interval** after dismiss
- [ ] Manual: temporarily shorten break interval for dev testing; confirm overlay appears on each screen and auto-dismisses

## Blocked by

- `issues/017-input-monitor-and-tick-loop.md`

## User stories addressed

- User story 24
- User story 25
- User story 26
- User story 27
- User story 28
- User story 29
- User story 32
- User story 33
