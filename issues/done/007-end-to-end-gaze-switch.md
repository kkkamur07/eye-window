---
id: "007"
title: "end-to-end-gaze-switch"
type: AFK
status: done
blocked_by:
  - "003-gaze-state-machine.md"
  - "005-permissions-camera-pipeline.md"
  - "006-focus-activation.md"
  - "002-dual-display-gating.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — full dependency flow: DisplayMonitor + HeadPoseEngine → GazeStateMachine → FocusController; **Focus indicator**; **SessionCoordinator** wiring.

## What to build

Wire live loop: pose stream + dual layout → **GazeStateMachine** → **FocusController** when intent fires and not paused. **Menu bar** shows **Focus indicator** `1` or `2` for current focus display. **SessionCoordinator** orchestrates modules; respects dual-only and session lifecycle. First dwell on a display uses **Focus fallback** if needed.

## Acceptance criteria

- [ ] With two displays, session active, camera on: dwell on other display moves keyboard focus to last-focused or fallback app there
- [ ] Menu bar shows `1` or `2` matching display with focus target after switch
- [ ] Focus lock prevents glance-steal during note-taking (manual spot-check)
- [ ] Not dual or session stopped → no gaze-driven activation
- [ ] Manual MVP tracer: video on one display, Obsidian on other — dwell to notes, type without Command+Tab once

## Blocked by

- `issues/003-gaze-state-machine.md`
- `issues/005-permissions-camera-pipeline.md`
- `issues/006-focus-activation.md`
- `issues/002-dual-display-gating.md`

## User stories addressed

- User story 1
- User story 2
- User story 3
- User story 4
- User story 5
- User story 6
- User story 9
- User story 14
- User story 18
