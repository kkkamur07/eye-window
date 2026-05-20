---
id: "002"
title: "dual-display-gating"
type: AFK
status: done
blocked_by:
  - "001-menu-bar-session.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **DisplayMonitor** module and dual-display gating in UI.

## What to build

**DisplayMonitor** detects connected displays and exposes `DualLayout` (left = display `1`, right = `2`) or `NotDual`. When session is active: exactly two displays → dual mode ready; zero, one, or three+ → switching disabled with clear menu bar state (warning/disabled, not `1`/`2` as focus indicator). Unit tests cover layout mapping without real hardware where possible.

## Acceptance criteria

- [x] `DisplayMonitor.currentDisplays()` returns dual layout with stable 1/2 when two screens connected per macOS global desktop order
- [x] Three or more, one, or zero displays → `NotDual`; gaze switching path not armed
- [x] Menu bar reflects not-dual state while session active (user-visible reason)
- [x] Unit tests: two-screen fixture → `DualLayout` with 1 left / 2 right; three-screen → `NotDual`
- [ ] Manual: unplug/replug or change arrangement updates state without restart

## Blocked by

- `issues/001-menu-bar-session.md`

## User stories addressed

- User story 10
- User story 18
- User story 19
- User story 29 (warn and disable beyond two)
