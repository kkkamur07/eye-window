---
id: "009"
title: "optional-debug-capture"
type: AFK
status: backlog
blocked_by:
  - "015-gaze-pipeline-e2e.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **Debug capture** behind flag in **GazeEngine** (optional face crop + yaw/pitch metadata).

## What to build

Developer-only flag (menu hidden item, compile flag, or defaults key): occasionally save camera frames or face crops (~10–20 s interval) for tuning calibration and gaze mapping. Does not affect live **Gaze stream** or **GazeStateMachine** timing.

## Acceptance criteria

- [ ] Flag off by default; no disk writes in normal use
- [ ] Flag on: sparse frame capture to local folder only; no network
- [ ] Live gaze switch latency unchanged with flag on (async/low priority)
- [ ] Document how to enable in dev notes

## Blocked by

- `issues/015-gaze-pipeline-e2e.md`

## User stories addressed

- User story 17
