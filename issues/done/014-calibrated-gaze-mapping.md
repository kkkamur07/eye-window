---
id: "014"
title: "calibrated-gaze-mapping"
type: AFK
status: done
blocked_by:
  - "013-calibration-heuristics.md"
  - "012-gaze-estimation-engine.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **CalibratedGazeMapping** in **GazeStateMachine**.

## What to build

Use **CalibrationStore** left/right yaw thresholds (midpoint between D1 and D2 samples) instead of only global `yawThresholdRadians`. Fall back to global threshold if calibration missing (should not happen after first-run flow). Update self-check for calibrated mapping cases.

## Acceptance criteria

- [x] After calibration, looking toward D1/D2 maps using stored thresholds, not fixed ±0.22 rad only
- [x] Center band between thresholds does not map to either display
- [x] Self-check covers calibrated left/right/mid cases
- [x] Logs include calibrated threshold values on session start (debug)

## Blocked by

- `issues/013-calibration-heuristics.md`
- `issues/012-gaze-estimation-engine.md`

## User stories addressed

- User story 5
- User story 20
- User story 27
