---
id: "010"
title: "mvp-readiness"
type: AFK
status: backlog
blocked_by:
  - "015-gaze-pipeline-e2e.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **MVP success**; **Testing Decisions** manual session; polish and constants.

## What to build

Final MVP pass after gaze model integration: tune dwell/constants if needed, verify battery-friendly inference cadence, run manual **MVP success** test checklist (30+ min dual-display study session with calibration). Fix sharp edges found in integrated use. Confirm out-of-scope items remain unimplemented.

## Acceptance criteria

- [x] `issues/MVP-SESSION-CHECKLIST.md` documents manual 30+ min test and success criteria from CONTEXT.md
- [x] Dwell default ~0.75 s documented as constant (not user setting) — see `GazeStateMachine.mediumDwellDuration`
- [ ] One real study session completed per checklist with notes on pause/Cmd+Tab frequency (requires you on hardware)
- [x] No scope creep: calibration, 3+ displays switching, cloud, login item, Flutter, window-level gaze absent
- [ ] Maintainer records pass/fail against stories 34–36 after manual session

## Blocked by

- `issues/015-gaze-pipeline-e2e.md`

## User stories addressed

- User story 33
- User story 34
- User story 35
- User story 36
- User story 39
