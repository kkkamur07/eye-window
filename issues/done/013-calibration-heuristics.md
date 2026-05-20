---
id: "013"
title: "calibration-heuristics"
type: AFK
status: done
blocked_by: []
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **Calibration heuristics**; **CalibrationStore**; menu D1 → D2 flow.

## What to build

Persist calibration data (yaw samples or derived left/right thresholds) to disk (UserDefaults or small JSON in Application Support). Menu bar flow: **Recalibrate**; on first session without data, auto-run “look at D1” then “look at D2” before arming gaze switch. Record yaw during each step (average or median over ~1 s). Expose `CalibrationStore` API for **GazeStateMachine** / mapper. UI strings in menu; coordinator gates switching until calibrated.

## Acceptance criteria

- [ ] First session without calibration runs D1 → D2 automatically; later sessions skip
- [ ] **Recalibrate** clears and reruns flow
- [ ] Thresholds persist across app restarts
- [ ] Pure tests: given two recorded yaw values → left/right thresholds → expected display side
- [ ] Menu shows calibration in progress vs ready

## Blocked by

None for store/UI shell; integration with live yaw blocked by `012-gaze-estimation-engine.md` (note in implementation).

## User stories addressed

- User story 20
- User story 21
- User story 22
