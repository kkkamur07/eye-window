---
id: "012"
title: "gaze-estimation-engine"
type: AFK
status: done
blocked_by:
  - "011-coreml-gaze-model.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **GazeEngine** replaces heuristic gaze inference in the camera pipeline.

## What to build

Replace Vision/heuristic yaw path in **HeadPoseEngine** with **GazeEngine** (rename acceptable): webcam → optional horizontal mirror per device type → Vision face rectangles → crop/preprocess → Core ML → `GazeSample` (yaw, pitch, onDisplayAttention from pitch). Keep ~5 FPS in-memory stream; no disk writes. Deprecate **HeadPoseMapper** for live path (keep or migrate tests).

## Acceptance criteria

- [x] Session produces gaze samples from Core ML, not face-center yaw heuristic
- [x] Face detection still Vision-only; no second detector
- [x] **On-display attention** derived from model pitch per CONTEXT.md (threshold documented as constant)
- [x] Built-in webcam mirrored; external USB cam unmirrored; rule fixed for session lifetime
- [x] `EyeWindowCoreSelfCheck` or unit tests cover pitch→attention and sample shape mapping where pure
- [x] `swift build` and `swift run EyeWindowCoreSelfCheck` pass

## Blocked by

- `issues/011-coreml-gaze-model.md`

## User stories addressed

- User story 19
- User story 23
- User story 24
- User story 25
- User story 32

## Deliverables

| Component | Path |
|-----------|------|
| Live pipeline | `Sources/EyeWindowCore/GazeEngine.swift` |
| Pure decode + attention | `Sources/EyeWindowCore/GazeInference.swift` (`GazeSample`, `GazeInference`, `CameraMirroring`) |
| Session wiring | `Sources/EyeWindowCore/SessionCoordinator.swift` |
| Deprecated heuristic | `Sources/EyeWindowCore/HeadPoseMapping.swift` (`HeadPoseMapper`) |
| Pitch attention constants | `GazeInference.pitchAttentionMinRadians` / `pitchAttentionMaxRadians` |
| I/O doc | `models/GAZE_MODEL_IO.md` |

**Mirroring:** `CameraMirroring.shouldMirrorHorizontally` — `false` for `externalUnknown`; otherwise mirror when `position == .front` (fixed at `GazeEngine.start()`).

**Attention:** pitch in `(-0.52, +0.26)` rad → `onDisplayAttention == true`.
