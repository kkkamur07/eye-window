---
id: "005"
title: "permissions-camera-pipeline"
type: AFK
status: done
blocked_by:
  - "001-menu-bar-session.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **HeadPoseEngine**; permissions UX; local-only **Head pose stream**.

## What to build

On session start, prompt for Camera (and document Accessibility for later slice). **HeadPoseEngine** captures webcam, runs on-device face/head pose at low FPS, exposes `poseStream() -> AsyncStream<HeadPose>` in memory only—no network, no photos on the control path. Menu shows blocked state if camera denied. Optional: log or debug UI that pose events arrive (no focus switch yet).

## Acceptance criteria

- [x] First session start triggers Camera permission when missing; denied → clear menu blocked state
- [x] With permission, pose stream yields yaw and on-display attention at low steady rate
- [x] No image persistence on hot path; no network calls
- [x] Stopping session stops capture pipeline
- [ ] Manual: grant camera, start session, observe pose activity indicator or debug log

## Blocked by

- `issues/001-menu-bar-session.md`

## User stories addressed

- User story 15
- User story 16
- User story 20 (camera portion)
- User story 25
- User story 28
- User story 33 (lightweight inference; no 10–20 s frame loop for switching)
