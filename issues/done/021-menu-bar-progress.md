---
id: "021"
title: "menu-bar-progress"
type: AFK
status: done
blocked_by: []
parent_prd: "issues/prd.md"
---

## Parent

`issues/prd.md` — **Menu bar progress**, **Blink status**.

## What to build

Show elapsed **Active usage time** and time until the next **Blink time** together in the menu dropdown, and show **Menu bar progress** as a fraction in the icon title alongside display focus.

**Dropdown** (replace current single blink line):
- Active: `Blink reminders: active · Active: 12m · Break in: 48m`
- Idle: `Blink reminders: idle · Active: 12m · Break in: 48m` (elapsed frozen, remaining reflects time left at stall)
- Paused: `Blink reminders: paused · Active: 12m · Break in: 48m` (both frozen)

**Icon title**: include **Menu bar progress** fraction using current **Eye break interval** — e.g. `Display Focus · D1 · 12/60` or compact `D1 · 12/60`. Fraction frozen when paused or in **Idle period**. Works with **Break interval** test presets (e.g. `8/30`).

Use existing **SessionCoordinator** published blink fields; formatting only in menu layer.

## Acceptance criteria

- [ ] Menu dropdown shows **Blink status** word (active / idle / paused) plus elapsed active usage and time until break
- [ ] Icon title includes progress fraction next to display focus indicator
- [ ] Fraction uses current **Eye break interval** (including menu preset); frozen when idle or paused
- [ ] Sub-minute intervals show seconds in "Break in" when under 60 s remaining
- [ ] `swift build` succeeds; display focus and blink tracking behavior unchanged
- [ ] Manual: active use → both times move; pause → frozen; change break interval preset → fraction denominator updates

## Blocked by

None — can start immediately.

## User stories addressed

- User story 30
- User story 31
- User story 32
- User story 33
- User story 34
- User story 35
