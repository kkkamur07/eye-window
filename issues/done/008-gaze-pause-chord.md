---
id: "008"
title: "gaze-pause-chord"
type: AFK
status: done
blocked_by:
  - "007-end-to-end-gaze-switch.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **HotkeyService**; **Gaze pause**; pause chord Control+Option+grave.

## What to build

**HotkeyService** registers global Control+Option+grave to toggle **Gaze pause**. While paused: no gaze-driven focus changes; user can use macOS normally; resume restores switching without new session. Menu reflects paused state. Camera pipeline may stop while paused (battery); must resume on unpause.

## Acceptance criteria

- [x] Chord toggles pause on/off globally while app running
- [x] Paused: dwell does not call **FocusController**
- [x] Unpaused: switching works again without restart session
- [x] Menu shows paused vs active gaze
- [ ] Manual: pause, Command+Tab freely, unpause, dwell switch still works

## Blocked by

- `issues/007-end-to-end-gaze-switch.md`

## User stories addressed

- User story 11
- User story 12
- User story 21
- User story 22
- User story 31 (pause is sole escape; no Cmd+Tab suppression)

## Review

**HotkeyService** (`Sources/EyeWindow/HotkeyService.swift`): Carbon `RegisterEventHotKey` for Control+Option+grave (`kVK_ANSI_Grave`); toggles `SessionCoordinator.toggleGazePause()` on press.

**SessionCoordinator**: `@Published isGazePaused`; pause stops `HeadPoseEngine` pipeline and clears pose label; unpause restarts pipeline when session active and camera authorized; `processPoseForGazeSwitch` and `isGazeSwitchingArmed` respect pause; `stopSession` resets pause.

**Menu bar**: status title `Eye Window · P` when paused; menu shows "Gaze paused" / "Gaze active"; pose line hidden while paused.

`swift build` passes. Manual end-to-end check (pause → Cmd+Tab → unpause → dwell) still pending.
