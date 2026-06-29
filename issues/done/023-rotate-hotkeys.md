---
id: "023"
title: "rotate-hotkeys"
type: AFK
status: done
blocked_by:
  - "022-focus-stack-core-selfcheck.md"
parent_prd: "issues/prd.md"
---

## Parent

`issues/prd.md` — **Rotate**; **Display switch chord**.

## What to build

Wire **Rotate** end-to-end on **Display switch chord** **⌘⌥1** / **⌘⌥2**:

- First press when keyboard focus is on the other **Display** → activate top of target **Focus stack** (current behavior).
- Repeated press while already on target **Display** → activate `nextForRotate` (wrap through full stack).
- Single-app stack on current **Display** → no-op; log e.g. `D2: only one app`.
- On app termination, eagerly remove from all **Focus stacks** so **Rotate** never targets quit apps.

**FocusController** activation path uses stack + current focus display/app from **SessionCoordinator** / **FocusObserver**. Log activation with app name. No **Focus stack** list in menu.

## Acceptance criteria

- [ ] **⌘⌥N** from other display → top of stack on display N
- [ ] Repeated **⌘⌥N** on same display cycles Obsidian → Safari → Terminal → Obsidian (wrap)
- [ ] Quit app removed from stack before next **Rotate**; no activation attempt on dead app
- [ ] Single-app **Rotate** is no-op with log line
- [ ] Manual clicks and Cmd+Tab still update **Focus stack** order
- [ ] `swift run DisplayFocusSelfCheck` still passes
- [ ] Manual dual-display test: cross-display switch + rotate cycle on notes display

## Blocked by

- `issues/022-focus-stack-core-selfcheck.md`

## User stories addressed

- User story 11
- User story 12
- User story 13
- User story 15
- User story 16
- User story 17
- User story 18
