---
id: "003"
title: "gaze-state-machine"
type: AFK
status: done
blocked_by:
  - "000-swift-foundation.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **GazeStateMachine**; dwell, focus lock, head-turn mapping, attention gating.

## What to build

Pure **GazeStateMachine** in core target: consumes `HeadPose` + `DualLayout`, emits `FocusIntent?` for display 1 or 2. Implements medium dwell (~0.75 s constant), focus lock, head-turn left/right mapping, and no intent when off-display attention. Comprehensive unit tests; no webcam or Accessibility.

## Acceptance criteria

- [x] Dwell not satisfied → no `FocusIntent`
- [x] Medium dwell on display N → intent for N
- [x] After switch, focus lock: brief opposite pose does not emit intent until medium dwell on other display
- [x] Off-display attention → no intent
- [x] Head yaw maps to left vs right display per `DualLayout`
- [x] All above covered by `EyeWindowCoreSelfCheck` without camera or AX

## Blocked by

- `issues/000-swift-foundation.md`

## User stories addressed

- User story 3
- User story 4
- User story 5
- User story 6
- User story 23 (display-level only; no window gaze)
