---
id: "016"
title: "active-usage-core-selfcheck"
type: AFK
status: done
blocked_by: []
parent_prd: "issues/prd.md"
---

## Parent

`issues/prd.md` — **ActiveUsageTracker**; **Testing Decisions** (highest seam).

## What to build

Land **ActiveUsageTracker** in **DisplayFocusCore** as the pure reducer for **Active usage time**. Extend **DisplayFocusSelfCheck** to verify end-to-end blink logic at the core boundary without AppKit or input hooks.

Cover: `recordActivity` seeds timing; repeated `tick` accumulates seconds only while not idle; no accumulation after **Idle threshold** without new activity; `remindersPaused` suppresses accumulation and **triggerBreak**; `overlayActive` suppresses tick accumulation; `completeBreak` resets **Active usage time** to zero; reaching **Eye break interval** returns **triggerBreak** effect.

Use a test-only **Active usage configuration** with shortened intervals inside self-check (e.g. 10 s break, 3 s idle) — production defaults remain five-minute idle and sixty-minute break per CONTEXT.md.

## Acceptance criteria

- [ ] **ActiveUsageTracker**, **ActiveUsageState**, **ActiveUsageConfiguration**, and **ActiveUsageEffect** are public in **DisplayFocusCore**
- [ ] Production defaults match CONTEXT.md: idle 300 s, break interval 3600 s
- [ ] `swift run DisplayFocusSelfCheck` passes all new preconditions plus existing ones
- [ ] `swift build` succeeds with no new dependencies
- [ ] No AppKit, event taps, or overlay code in this slice

## Blocked by

None — can start immediately.

## User stories addressed

- User story 16
- User story 17
- User story 18
- User story 19
- User story 22
- User story 24
- User story 29
