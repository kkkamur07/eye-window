# Eye Window

Head- and face-driven keyboard focus on macOS for multi-display workflows, so you can look at a screen and type there without Command+Tab. MVP does not require dedicated eye tracking hardware or per-eye gaze models.

## Principles

**MVP simplicity**:
Ship the smallest set of behaviors that proves the study workflow; prefer fewer features and fewer settings over completeness. Improve only after **MVP success**.
_Avoid_: Minimal Viable Product (acronym), KISS (too generic)

## Language

**Display**:
A physical monitor connected to the Mac, identified as a screen rectangle in the global desktop space.
_Avoid_: Screen (ambiguous with app window), monitor (hardware-only connotation)

**Focus target**:
The application that receives keyboard input after a gaze-driven switch.
_Avoid_: Active window (implementation-specific), frontmost app (only one definition of focus)

**Display-level focus** (MVP scope):
Switching **Focus target** based on which **Display** the user is looking at, not which window or region within a display.
_Avoid_: Window-level focus, gaze-to-window

**Dwell**:
Head orientation toward a **Display** held for a minimum duration before a focus switch is considered intentional. MVP uses **Medium dwell** (~0.7–0.9 s).
_Avoid_: Delay, debounce (implementation terms)

**Medium dwell**:
The default **Dwell** duration for MVP—long enough to avoid accidental switches with **Head-turn mapping**, short enough to feel responsive when taking notes.
_Avoid_: Slow mode, 750 ms

**Focus lock**:
After a dwell switch, the **Focus target** stays on that **Display** until the user dwells on a different **Display**; brief glances elsewhere do not switch focus.
_Avoid_: Sticky mode, hysteresis (implementation terms)

**Last-focused app** (per display):
The application that most recently held keyboard focus while its window was on that **Display** during the current **Session**.
_Avoid_: Frontmost app, top window, active app

**Focus fallback**:
When no **Last-focused app** is known yet for a **Display** in this **Session**, activate the frontmost app on that **Display**.
_Avoid_: Default app, first launch rule

**Last-focused tracking**:
During a **Session**, whenever **Focus target** changes on a **Display**—by gaze, click, keyboard, or any other means—the **Eye Window app** updates **Last-focused app** for that **Display**.
_Avoid_: Focus watcher, AX observer

**Webcam**:
The physical USB or built-in video camera used for **Gaze source** (desk webcam for MVP—not phone camera, not screen capture). MVP uses the system default video device unless the user picks another in **Menu bar control** later.
_Avoid_: Camera (too generic), FaceTime camera (device-specific), iPhone Continuity Camera

**Gaze source**:
The **Webcam** pipeline that estimates where the user is looking: a local **Gaze estimation model** (face crop → yaw/pitch) plus **Calibration heuristics** to map angles to this desk setup. No dedicated eye-tracking hardware.
_Avoid_: Tracker, sensor, Vision-only head pose (replaced for MVP)

**On-display attention**:
Whether the user is looking toward a **Display** vs away (phone, desk, wall), inferred from the **Gaze estimation model** (especially **pitch** in the **Gaze stream**)—not from face-size or other Vision heuristics. Distinct from which **Display** within a multi-monitor setup.
_Avoid_: Looking at screen, face bounding-box width, Vision-only attention

**Gaze estimation model**:
A small on-device network (MVP: MobileNetV2 from MobileGaze) that takes a cropped face image and outputs horizontal (**yaw**) and vertical (**pitch**) gaze angles. Powers the **Gaze stream**; runs under **Local-only processing**.
_Avoid_: L2CS, ONNX file name, PyTorch

**Gaze stream**:
A continuous, in-memory sequence of gaze samples (**yaw**, **pitch**, and **On-display attention**) produced by the **Gaze estimation model** at low frame rate. Powers **Dwell** and **Gaze mapping**; Vision is used only to locate the face crop, not to estimate gaze angles.
_Avoid_: Head pose stream (superseded term), video recording, Vision yaw

**Camera mirroring** (MVP):
Some **Webcam** frames are horizontally mirrored before face detection and gaze inference (typically built-in front-facing cameras). The mirror rule is **fixed per device** for the whole **Session** and **Calibration heuristics**—it must never toggle mid-session; a flip change would invalidate yaw mapping. External desk webcams are usually not mirrored.
_Avoid_: Auto-detect flip per frame, flip only during calibration, toggling mirror mid-**Session**

**Calibration heuristics** (MVP):
A short per-display flow in **Menu bar control**: a **calibration dot** on each **Display** center (~2.5 s); the app records **Gaze stream** samples `[gx, gy, gz, gaze yaw, pitch]` and stores mean prototype vectors per display. Runtime **Gaze mapping** uses nearest-prototype distance plus mode smoothing (last 10 frames). Dual-display: D1 then D2 (no third “center” target). Done once per desk setup; **Recalibrate** in the menu when layout changes.
_Avoid_: Training, fine-tuning the model, auto-drift learning, calibrate-on-every-session, Vision head-yaw-only thresholds

**Head-turn mapping** (MVP **Gaze mapping**):
Which **Display** is selected from **Gaze stream** yaw (left vs right) against known **Display** layout, adjusted by **Calibration heuristics**.
_Avoid_: Gaze ray to desktop pixel, eye vector

**Dual-display mode** (MVP):
**Head-turn mapping** and focus switching operate only when exactly two **Displays** are connected; otherwise the **Eye Window app** does not switch **Focus target** and informs the user via **Menu bar control**.
_Avoid_: Multi-monitor mode, 2-up

**Eye Window app**:
The native macOS application that reads **Gaze source**, applies **Dwell** and **Focus lock**, and activates the **Last-focused app** on the chosen **Display**. MVP is native-only; no browser dependency for focus control.
_Avoid_: Web app, helper, agent (unless we split roles later)

**Menu bar control**:
The primary UI for the **Eye Window app**—status item for start/stop **Session**, **Gaze pause**, settings, and quit—without a main document window (similar to Rectangle-style utilities).
_Avoid_: Dock app, main window, dashboard

**Focus indicator**:
A subtle **Menu bar control** label showing which **Display** currently holds **Focus target** (e.g. display number `1` or `2` in **Dual-display mode**).
_Avoid_: HUD, toast, notification

**Display number**:
A stable 1-based label for each **Display** in **Dual-display mode**, derived from macOS desktop layout (left **Display** = `1`, right = `2`).
_Avoid_: Monitor ID, screen index, role-based numbering

**Gaze pause**:
Gaze-driven switching is suspended; **Focus target** changes only via normal macOS input (mouse, keyboard, Mission Control) until the user resumes. Toggled via the **Pause chord**.
_Avoid_: Disable, off switch, kill switch

**Pause chord**:
The global keyboard shortcut that toggles **Gaze pause** (MVP: Control+Option+grave, left-hand chord).
_Avoid_: Hotkey, shortcut, binding

**Gaze mapping**:
The rule that turns **Gaze source** output into “which **Display** is being looked at.” MVP uses **Head-turn mapping**; **Calibration** is post-MVP.
_Avoid_: Calibration (reserved for the guided setup flow later)

**Calibration** (full, post-MVP):
A guided session where the user looks at each **Display** so **Gaze mapping** can be tuned beyond **Calibration heuristics**.
_Avoid_: Setup wizard, training the **Gaze estimation model**


**Debug capture** (optional):
Occasional saved camera frames (e.g. every 10–20 s) for development tuning only; not used for focus switching.
_Avoid_: Screenshot, logging interval

**Session**:
A period when the user has launched the **Eye Window app** and gaze-driven switching may run (subject to **Gaze pause**). MVP starts a **Session** manually; no login-item auto-start.
_Avoid_: Login item, daemon, background service

**Local-only processing**:
All **Gaze stream** inference and focus decisions run on the Mac; no camera frames or face data are sent to the network.
_Avoid_: On-device, offline mode, privacy mode

**MVP success**:
The user completes one real study session (30+ minutes, course + notes) in **Dual-display mode** with gaze-driven switching, needing **Gaze pause** at most occasionally and rarely using Command+Tab to correct focus.
_Avoid_: Done, shipped, v1

## Relationships

- The **Eye Window app** depends on **Gaze source** and macOS permissions to change **Focus target**
- **Gaze pause** stops the **Eye Window app** from changing **Focus target** until the user resumes
- A **Session** begins when the user launches the **Eye Window app**; ends when they quit
- The user operates the **Eye Window app** through **Menu bar control** during a **Session**
- **Local-only processing** applies to the entire **Gaze stream**, **Gaze estimation model**, and **Debug capture**
- **Display number** follows macOS left-to-right layout and drives the **Focus indicator**
- **MVP success** is validated by one real study **Session**, not only technical smoke tests
- **Last-focused tracking** keeps **Last-focused app** accurate for manual and gaze-driven focus changes
- **Gaze mapping** links **Gaze stream** to a **Display** via **Head-turn mapping** and **Calibration heuristics**; full **Calibration** is post-MVP
- **On-display attention** gates whether **Head-turn mapping** is trusted (ignore focus changes when the user is not attending to any **Display**)
- **Gaze estimation model** produces yaw/pitch; **Gaze stream** feeds **Dwell** and **Head-turn mapping**
- All MVP scope choices defer to **MVP simplicity** until **MVP success** is met

- **Gaze source** determines which **Display** the user is looking at; MVP prefers built-in or external **webcam**, with dedicated eye tracker as a later **Gaze source**

- Gaze on a **Display** may change the **Focus target** to the **Last-focused app** on that **Display**, after **Dwell** and subject to **Focus lock**; if none known, **Focus fallback** applies
- MVP supports only **Display-level focus**; window-level routing is out of scope
- **Focus lock** applies after a successful dwell-based switch until the next dwell on another **Display**

## Example dialogue

> **Dev:** "User looks at the Obsidian **Display** while YouTube is on another **Display** — what gets **Focus target**?"
> **Domain expert:** "The **Last-focused app** on that **Display** — Obsidian — even if another window briefly covered it."
>
> **Dev:** "User glances at YouTube for a second while typing in Obsidian — does focus jump?"
> **Domain expert:** "No — **Focus lock** holds Obsidian until they dwell on the course **Display** again."
>
> **Dev:** "Where do I turn it off mid-lecture?"
> **Domain expert:** "**Menu bar control** — pause from the icon or the hotkey, same as other menu bar utilities."
>
> **Dev:** "How do I know focus moved?"
> **Domain expert:** "The **Focus indicator** shows the **Display number**—`1` or `2`—for whichever **Display** has **Focus target**."

## Flagged ambiguities

- "Native" was used to mean "no Accessibility permission" — resolved: macOS still requires Accessibility (and camera) for the **Eye Window app** regardless of UI toolkit.
- **Calibration** deferred post-MVP; MVP uses **Head-turn mapping** not geometry-only desktop ray casting.
- "Eye tracking" in conversation sometimes means **Gaze source** — resolved: MVP uses **Gaze estimation model** (learned yaw/pitch), not a hardware eye tracker.
- Inference cadence vs **Dwell** — resolved: **Gaze stream** runs continuously in memory; **Debug capture** is optional and separate.
- Vision-only head pose — resolved: replaced by **Gaze estimation model**; **Calibration heuristics** only, not retraining.
- Model runtime on Mac — resolved: **Gaze estimation model** authored as ONNX; shipped as a pre-converted on-device model (Core ML) beside the ONNX source; Swift loads the converted artifact—no Python or convert-on-build at runtime.
- **Calibration heuristics** — resolved: two-step “look at D1 / look at D2” in menu; thresholds persisted; not fixed global cutoffs alone.
- Face detection for gaze crop — resolved: Apple Vision face rectangles only for MVP; no second detector model.
- Gaze angles and attention — resolved: **yaw**, **pitch**, and **On-display attention** come from the **Gaze estimation model**; Vision does not estimate gaze.
- **Webcam** scope — resolved: **Gaze source** uses the user’s **Webcam** (default system video device; built-in or USB desk cam).
- **Camera mirroring** — resolved: mirror built-in front-facing **Webcam** only; external desk cams unmirrored; rule fixed for the whole **Session** and calibration (never toggles mid-**Session**).
- **Dwell** / **Focus lock** after gaze model — resolved: keep existing timing and lock rules; only replace the **Gaze stream** signal.
- When to calibrate — resolved: once per desk setup (persisted), not at every **Session** start.
- First **Session** without calibration — resolved: **Start session** runs the D1 → D2 flow automatically, then gaze proceeds; later starts skip unless user chooses **Recalibrate**.
- Which **Displays** participate — resolved: MVP **Dual-display mode** only.
- Repository path under `python/` is organizational only; not a language choice for the **Eye Window app**.
