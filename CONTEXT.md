# Eye Window

Menu bar utility for dual-display focus switching and eye-health break reminders.

## Language

### Display focus

**Display**: Monitor 1 or 2 in macOS display numbering.

**Focus target**: App receiving keyboard input after a switch.

**Last-focused app**: Most recently focused app on that **Display** this run; top of the **Focus stack**.

**Focus stack**: Every app that has held focus on a **Display** this run, ordered most recent first, deduped (re-focus moves an app back to the top). Quit apps are removed from the stack as soon as they exit. **Rotate** cycles through the full stack and wraps from the bottom to the top.

**Rotate**: On repeated **Display switch chord** for the **Display** that already has keyboard focus, activate the next app in that **Display**'s **Focus stack** instead of the top entry again. If the stack has only one app, **Rotate** is a no-op.

**Display switch chord**: **⌘⌥1** / **⌘⌥2** (Command+Option+number; avoids Arc ⌘1/⌘2). First press on a **Display** you are not on activates the top of its **Focus stack**; repeated press while already on that **Display** **Rotate**s. More chords: add rows to `HotkeyService.bindings`.

**Dual-display mode**: Exactly two active displays; otherwise hotkeys log a warning.

**Accessibility permission**: Required to activate apps.

### Eye health

**Active usage time**: Elapsed time while the user is actively using the computer — keyboard, mouse, scroll, or similar input — not wall-clock time.

**Idle period**: Stretch with no keyboard, mouse, or scroll input; **Active usage time** does not accumulate during an **Idle period**.

**Idle threshold**: Five minutes of no input before an **Idle period** begins.

**Eye break**: A full-screen interruption triggered after enough **Active usage time** has accumulated.

**Blink time**: The single **Eye break** message shown to the user — a reminder to blink and apply eye drops as part of one ritual.
_Avoid_: Drop time (same break; "blink time" is the canonical label)

**Eye break interval**: Sixty minutes of **Active usage time** before the next **Blink time**.

**Blink time overlay**: Full black screen on every **Display**, with the **Blink time** message centered; blocks interaction until the overlay ends.

**Overlay duration**: Forty-five seconds per **Blink time**.

**Skip**: End a **Blink time overlay** before **Overlay duration** elapses; requires user confirmation before dismissing.

**Blink reminders**: Eye-health tracking and **Blink time** overlays; **always on** while the app is running, with a menu toggle to pause.

**Blink status**: Whether **Blink reminders** are actively accumulating, in an **Idle period**, or paused — shown in the menu bar alongside elapsed **Active usage time** and time until the next **Blink time**.

**Menu bar progress**: Elapsed **Active usage time** over the current **Eye break interval**, shown as a fraction (e.g. `12/60`) in the icon title next to the current **Display** focus. Full elapsed and remaining times appear in the menu dropdown.

**Overlay message**: **Blink time** · Use your eye drops. Without your eyes, you can't look at this screen forever.

## Relationships

### Display focus

- **Last-focused app** is the top entry of each **Display**'s **Focus stack**.
- **Rotate** only applies when keyboard focus is already on the target **Display**; switching from the other **Display** always lands on the top of the **Focus stack**.
- The **Focus stack** is not shown in the menu; display focus is driven entirely by **Display switch chord** hotkeys.

### Eye health

- **Active usage time** accumulates toward an **Eye break**; it pauses during an **Idle period** (after the **Idle threshold**).
- One **Eye break** type: **Blink time** (not separate drop/blink schedules).
- After **Blink time**, **Active usage time** resets toward the next **Eye break interval**.
- **Blink reminders** run whenever the app is running unless paused from the menu.
- **Menu bar progress** uses the current **Eye break interval** (including any testing preset). When **Blink reminders** are paused or in an **Idle period**, the fraction shows the last accumulated value (frozen).
- **Skip** on an overlay shows a confirmation step before the overlay closes.
- After a **Blink time** ends (timer elapsed or confirmed **Skip**), **Active usage time** resets to zero.
