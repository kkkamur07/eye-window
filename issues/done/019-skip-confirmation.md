---
id: "019"
title: "skip-confirmation"
type: AFK
status: done
blocked_by:
  - "018-blink-time-overlay.md"
parent_prd: "issues/prd.md"
---

## Parent

`issues/prd.md` — **Skip** on **Blink time overlay**.

## What to build

Add **Skip** to the **Blink time overlay**. Tapping **Skip** does not dismiss immediately — show a confirmation step (alert or in-overlay confirm/cancel). Only on confirm: dismiss all overlay windows, call `completeBreak`, and reset **Active usage time** to zero. Cancel returns to the overlay with remaining **Overlay duration** (or paused timer — pick one behavior and document in menu log).

Accidental click on **Skip** alone must not end **Blink time**.

## Acceptance criteria

- [ ] **Skip** control visible on every overlay window (or one shared control that dismisses all)
- [ ] First **Skip** press shows confirmation; cancel keeps overlay up
- [ ] Confirm dismisses all overlays and resets **Active usage time**
- [ ] Natural forty-five-second completion still works unchanged
- [ ] Manual: trigger overlay, press **Skip**, cancel, confirm; verify reset only on confirm

## Blocked by

- `issues/018-blink-time-overlay.md`

## User stories addressed

- User story 29
- User story 30
- User story 31
