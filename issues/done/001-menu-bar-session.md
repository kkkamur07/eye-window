---
id: "001"
title: "menu-bar-session"
type: AFK
status: done
blocked_by:
  - "000-swift-foundation.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **MenuBarPresenter**, **SessionCoordinator** (lifecycle only).

## What to build

End-to-end menu bar control: user can start and stop a **Session** from the status item menu; quit exits the app. **SessionCoordinator** owns started/stopped state; menu reflects idle vs active session. No camera, gaze, or focus switching yet.

## Acceptance criteria

- [x] Status item menu includes Start session, Stop session (enabled appropriately), and Quit
- [x] Starting a session sets coordinator state; stopping clears it; no crash on repeat start/stop
- [x] Menu label or subtitle indicates session inactive vs active (not yet `1`/`2` focus numbers)
- [x] App does not register login item or auto-start (story 26)
- [x] Manual: launch app, start/stop session, quit — all work without permissions granted

## Blocked by

- `issues/000-swift-foundation.md`

## User stories addressed

- User story 7
- User story 8
- User story 27 (native menu bar only; no Flutter)
