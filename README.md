# Display Focus

A small macOS menu bar app for **two-monitor** workflows. Jump keyboard focus between displays with **⌘⌥1** and **⌘⌥2** instead of hunting through Cmd+Tab.

No webcam, no ML, no calibration — just hotkeys and focus memory.

---

## Shortcuts

| Shortcut | Action |
|----------|--------|
| **⌘⌥1** | Focus last app on **display 1** |
| **⌘⌥2** | Focus last app on **display 2** |

Why **⌘⌥** and not **⌘** alone? Arc (and many browsers) use **⌘1 / ⌘2** for tabs. **⌥1** alone types symbols (¡, ™, £) on macOS.

---

## Setup

1. **Two displays** connected (exactly two; three or more disables switching).
2. **Build and run** (see below).
3. **Accessibility** — allow when prompted (needed to activate apps).
4. **Click once** on an app on each display so Display Focus knows what to restore.
5. Use **⌘⌥1** / **⌘⌥2** anytime.

Hotkeys and focus tracking start **as soon as the app launches** — you do not need to open the menu bar menu first.

**Open at login** is enabled by default. Toggle it in the menu. If macOS asks, approve Display Focus under **System Settings → General → Login Items**.

Normal Cmd+Tab and clicks still update which app is remembered per display.

---

## Run

**Requirements:** macOS 13+, Swift 5.9+

```bash
git clone https://github.com/kkkamur07/eye-window.git
cd eye-window
swift build
swift run DisplayFocus
```

With logs in the terminal:

```bash
swift run DisplayFocus 2>&1
```

You should see `ready (⌘⌥1 · ⌘⌥2)` immediately after launch.

Optional self-check:

```bash
swift run DisplayFocusSelfCheck
```

---

## Menu bar

The **rectangle** icon in the menu bar shows current focus (e.g. `Display Focus · D1 · Cursor`). Open it for:

- Status and recent log lines
- **Open at login** toggle
- Manual “Focus display 1 / 2” buttons
- Quit

---

## Troubleshooting

| Issue | What to do |
|-------|------------|
| Hotkeys do nothing | Confirm two displays; check terminal for `hotkey register failed` |
| `D1: click an app on that display once` | Click any app on that display, then retry |
| Accessibility blocked | System Settings → Privacy & Security → Accessibility → enable Display Focus |
| Wrong display number | Display 1/2 follow macOS numbering in **System Settings → Displays** |
| Login item missing | Menu → turn **Open at login** off and on; approve in Login Items |

---

## Project layout

| Path | Role |
|------|------|
| `Sources/DisplayFocus/` | Menu bar app, hotkeys, launch-at-login, focus activation |
| `Sources/DisplayFocusCore/` | Display detection, per-display focus history |
| `Sources/DisplayFocus/HotkeyService.swift` | Add more shortcuts via the `bindings` table |

---

## Adding hotkeys

Edit `bindings` in `Sources/DisplayFocus/HotkeyService.swift`:

```swift
private static let bindings: [(keyCode: UInt32, action: Action)] = [
    (UInt32(kVK_ANSI_1), .focusDisplay1),
    (UInt32(kVK_ANSI_2), .focusDisplay2),
]
```

Add a new `Action` case and handler in `AppModel` for a third display when you extend support.

---

## License

See repository license file if present.
