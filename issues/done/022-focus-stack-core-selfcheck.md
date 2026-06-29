---
id: "022"
title: "focus-stack-core-selfcheck"
type: AFK
status: done
blocked_by: []
parent_prd: "issues/prd.md"
---

## Parent

`issues/prd.md` — **Focus stack**; **Testing Decisions** (highest seam for rotate logic).

## What to build

Extend **FocusHistory** from a single **Last-focused app** per **Display** to a full session **Focus stack**: ordered most-recent-first, deduped on record (re-focus moves app to top), `remove(app)` for eager prune.

Pure API for **Rotate** index logic (no AppKit):
- `stack(for display)` → ordered **AppRef** list
- `lastFocused(display)` → top of stack (backward compatible)
- `nextForRotate(display:currentApp:)` → next app wrapping to top; nil or same when stack count ≤ 1 (no-op signal)

Extend **DisplayFocusSelfCheck** to verify: record A, B, C on display 2 → order C, B, A; re-record B → B, C, A; remove B → C, A; rotate from C → A; rotate from A → C (wrap); single-app stack → no next.

No hotkey wiring or termination observer in this slice.

## Acceptance criteria

- [ ] **FocusHistory** exposes stack operations; existing `lastFocused` callers still work
- [ ] Dedupe move-to-top on `recordFocusChange`
- [ ] `nextForRotate` wraps; returns no-op signal when stack has one app
- [ ] `remove` drops app from stack without affecting others' order
- [ ] `swift run DisplayFocusSelfCheck` passes all new and existing preconditions
- [ ] No **Rotate** hotkey behavior change yet (stack populated but activation still top-only until 023)

## Blocked by

None — can start immediately.

## User stories addressed

- User story 14
- User story 15
- User story 19
