---
id: "000"
title: "swift-foundation"
type: AFK
status: done
blocked_by: []
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md`

## What to build

Greenfield Swift macOS project in this repository: menu-bar accessory app target plus a small `EyeWindowCore` (or equivalent) library target for pure logic modules. Project builds and launches with a placeholder status item; no gaze or focus behavior yet. Satisfies **Implementation Decisions** technology choices and user story 37.

## Acceptance criteria

- [x] Xcode/Swift package layout lives in-repo; app builds from a documented one-command or Xcode flow
- [x] Menu bar agent launches without a main document window
- [x] `EyeWindowCore` (or named equivalent) target exists for unit-testable modules
- [x] Test target wired and runs (smoke test passes via Swift Testing)
- [x] README or inline doc notes Camera/Accessibility will be required later (no implementation in this slice)

## Blocked by

None — can start immediately.

## User stories addressed

- User story 37
- User story 38 (repo structure; CONTEXT.md already present)
