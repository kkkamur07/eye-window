---
id: "004"
title: "focus-history"
type: AFK
status: done
blocked_by:
  - "000-swift-foundation.md"
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **FocusHistory**; session-scoped last-focused per display.

## What to build

**FocusHistory** tracks **Last-focused app** per display for the current session only: `recordFocusChange(app, display)` and `lastFocused(display) -> AppRef?`. No persistence across app restart. Unit tests for record/query and session reset on new session.

## Acceptance criteria

- [x] Recording focus on display 1 then querying display 1 returns that app ref
- [x] Separate displays maintain independent last-focused entries
- [x] New session clears history (no cross-session persistence)
- [x] `EyeWindowCoreSelfCheck` covers record, query, reset without AX
- [x] Ready for **FocusObserver** and **FocusController** to call record API

## Blocked by

- `issues/000-swift-foundation.md`

## User stories addressed

- User story 2
- User story 13
- User story 30
