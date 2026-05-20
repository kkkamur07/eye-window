---
id: "015"
title: "gaze-pipeline-e2e"
type: AFK
status: done
blocked_by:
  - "014-calibrated-gaze-mapping.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **SessionCoordinator** end-to-end gaze pivot; retire heuristic path.

## What to build

Wire **GazeEngine** + **CalibrationStore** + calibrated **GazeStateMachine** through **SessionCoordinator** and menu bar (gaze status, logs). Remove or stop using heuristic **HeadPoseMapper** on live path. Update README for calibration first-run and recalibrate. Verify dual-display gating, dwell, focus lock, and focus activation still work with model gaze.

## Acceptance criteria

- [ ] Start session on dual displays: calibration if needed, then gaze-driven focus switch works on hardware smoke test
- [x] Menu shows mapped display, dwell progress, active app, recent logs with model-based yaw
- [x] Gaze pause still stops pipeline; resume restarts gaze
- [x] `swift run EyeWindowCoreSelfCheck` passes
- [x] README documents first-run calibration and Recalibrate

## Blocked by

- `issues/014-calibrated-gaze-mapping.md`

## User stories addressed

- User stories 1–4, 9, 17–18, 26
- User story 33 (enables manual MVP test)
