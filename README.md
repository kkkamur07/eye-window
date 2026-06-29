# Display Focus (Eye Window)

A small Mac menu bar app for two-monitor work and gentle eye-break reminders.

No webcam. No cloud. Everything stays on your Mac.

---

## What it does

### Jump between displays

If you use two monitors, press:

| Shortcut | What happens |
|----------|----------------|
| **⌘⌥1** | Jump to the last app you used on display 1 |
| **⌘⌥2** | Jump to the last app you used on display 2 |

This avoids digging through Cmd+Tab when you already know which screen you want.

**Note:** Hotkeys only work with exactly **two** displays connected.

### Blink break reminders

After enough time at the computer, a full-screen **Blink time** overlay appears on every display:

> Blink time · Use your eye drops. Without your eyes, you can't look at this screen forever.

You can wait for it to finish (~45 seconds) or skip with confirmation. After a break, the timer resets.

---

## Tracking modes

You pick how the break timer counts in the menu:

| Mode | How it works |
|------|----------------|
| **Clock** (default) | Counts continuously while reminders are on |
| **Keyboard & mouse** | Only counts when you are typing, clicking, or moving the mouse. Pauses after 5 minutes of no input. |

**Clock** needs no extra permission.

**Keyboard & mouse** needs **Input Monitoring** in System Settings.

---

## Install and run

**Requirements:** macOS 13+, Swift 5.9+

```bash
git clone https://github.com/kkkamur07/eye-window.git
cd eye-window
chmod +x scripts/install-app.sh
./scripts/install-app.sh
open "/Applications/Display Focus.app"
```

The install script builds the app, copies it to `/Applications/Display Focus.app`, and adds the eye icon.

For development without installing:

```bash
swift run DisplayFocus
```

---

## First-time setup

1. **Run the app** (install script above, or `swift run DisplayFocus`).
2. **Accessibility** — allow when prompted. Needed for display focus hotkeys.
3. **Input Monitoring** — only if you use **Keyboard & mouse** tracking.
4. **Two displays** — connect both monitors for hotkeys.
5. **Click once** on an app on each display so the app remembers what to switch to.

**Open at login** is on by default. Toggle it in the menu if you prefer.

---

## Using the menu

Click the **eye icon** in the menu bar.

You will see:

- Current focus and blink timer status
- **Tracking mode** — tap Clock or Keyboard & mouse (checkmark shows the active one)
- **Break interval** — 60 min (default), 5 min, 2 min, or 30 sec for testing
- **Pause / Resume blink reminders**
- **Open at login**
- **Quit**

The menu bar also shows progress like `2/60` (minutes elapsed out of total).

---

## Permissions

| Permission | Needed for |
|------------|------------|
| **Accessibility** | Display focus hotkeys |
| **Input Monitoring** | Keyboard & mouse tracking only |

If something does not work, check **System Settings → Privacy & Security**.

---

## Quick test

Automated logic check (no permissions needed):

```bash
swift run DisplayFocusSelfCheck
```

Expected output: `DisplayFocusSelfCheck OK`

Manual blink test:

1. Open the menu → set break interval to **30 seconds (test)**
2. Wait or stay active (depends on tracking mode)
3. Confirm the black blink overlay appears on all displays
4. Set interval back to **60 minutes** when done

---

## Troubleshooting

| Problem | Try this |
|---------|----------|
| Hotkeys do nothing | Connect exactly 2 displays. Grant Accessibility. |
| `click an app on that display once` | Click any app on that screen, then retry the hotkey. |
| Timer stuck at 0 in keyboard mode | Allow Input Monitoring for Display Focus. |
| No eye icon in menu bar | Re-run `./scripts/install-app.sh` from `/Applications`. |
| Wrong display number | Check **System Settings → Displays** for monitor order. |

---

## Project layout

| Folder | What it is |
|--------|------------|
| `Sources/DisplayFocus/` | Menu bar app, hotkeys, blink overlay |
| `Sources/DisplayFocusCore/` | Shared logic (displays, timers, focus history) |
| `Sources/DisplayFocus/Resources/` | App icon and menu bar icon |
| `scripts/install-app.sh` | Build and install to `/Applications` |

---

## License

See the repository license file if present.
