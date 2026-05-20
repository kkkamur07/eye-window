# Eye Window — Product Requirements Document (Gaze Model MVP)

## Problem Statement

When working across two monitors—for example, a video course on one display and Obsidian on another—switching keyboard focus requires repeated Command+Tab every time you look at the other screen to take notes. That breaks flow during lectures and study sessions.

An initial MVP shipped with Vision-based head-pose heuristics (face position and optional face yaw). In real use, focus switches too often and feel wrong: the menu bar shows activity, but **display-level focus does not reliably follow where the user is looking**. The user needs **learned gaze estimation** (yaw/pitch from a small on-device model) plus **lightweight calibration** for their desk setup, while keeping everything local, private, and menu-bar simple.

## Solution

Eye Window remains a native macOS menu bar utility. During a manually started **Session** with exactly two **Displays**, it uses the user’s **Webcam** and a **Gaze estimation model** (MobileNetV2 / MobileGaze, ONNX source converted to Core ML) to produce a **Gaze stream** (yaw, pitch, **On-display attention**). Apple Vision supplies face rectangles only—to crop the face for the model, not to estimate gaze angles.

On first **Session** without saved **Calibration heuristics**, the app runs a two-step flow: look at display 1, then display 2; recorded yaw samples derive left/right thresholds for **Gaze mapping**. Later **Sessions** reuse persisted thresholds; **Recalibrate** is available from the menu when the desk setup changes.

Existing behavior is retained where it still applies: **Medium dwell** (~0.9 s) with stable frames, **Focus lock**, **Last-focused app** per display, **Focus fallback**, **Gaze pause** (Control+Option+grave), **Focus indicator** and debug logs in the menu bar (display number + active app name), and **Dual-display mode** gating. **Camera mirroring** is fixed per webcam type for the whole **Session** (built-in mirrored, external desk cam unmirrored)—never toggling mid-session.

**MVP success** is unchanged: one real 30+ minute course-and-notes **Session** with gaze-driven switching, **Gaze pause** only occasionally, and rarely correcting focus with Command+Tab.

## User Stories

### Study workflow (unchanged goals)

1. As a student watching a course on one display, I want keyboard focus to move to my notes display when I look at it long enough, so that I can type without Command+Tab.

2. As a student, I want focus to return to the last app I used on each display, so that Obsidian stays targetable even if another window briefly covered it.

3. As a student, I want a brief glance at the video display while typing notes not to steal focus, so that focus lock holds until I deliberately dwell on the other display.

4. As a student, I want focus switching to require a medium dwell before activating, so that accidental movements do not change focus constantly.

5. As a student with exactly two monitors, I want gaze mapped to left vs right display, so that dual-monitor study is supported.

6. As a student, I want the app to avoid switching when I am not attending my monitors (phone, desk, wall), so that focus does not change when I am away.

7. As a student, I want to launch the app when I start studying and quit when done, so that the camera is not always on.

8. As a student, I want to control the app from the menu bar like Rectangle, so that it stays out of the way.

9. As a student, I want the menu bar to show which display number (1 or 2) has focus and which app is active, so that I can trust or debug switches.

10. As a student, I want display numbers to match macOS left-to-right layout, so that 1 and 2 match System Settings.

11. As a student, I want to pause gaze-driven switching with Control+Option+grave, so that I can recover when detection is wrong.

12. As a student, I want manual clicks and Command+Tab to update last-focused per display, so that gaze returns to the app I actually use.

13. As a student, I want the first dwell on a display to focus a sensible app if none is known yet this session, so that I am not stuck.

14. As a student, I want all camera and gaze processing on my Mac only, so that nothing is sent to the cloud.

15. As a student with zero, one, or three+ displays, I want switching disabled and a clear menu state, so that I am not surprised.

16. As a student, I want to grant Camera and Accessibility when prompted, so that gaze and focus activation work.

17. As a student, I want gaze pause to stop automatic switching while still using macOS normally, so that I can finish a task without quitting.

18. As a student, I want to resume gaze after pause without restarting the session, so that I can return to hands-free focus.

### Gaze model and calibration (new / updated)

19. As a student, I want gaze direction from a trained model (not face-position heuristics), so that left/right display detection matches where I look.

20. As a student setting up for the first time, I want a short “look at display 1, then display 2” calibration in the menu, so that thresholds fit my webcam and desk without retraining the model.

21. As a student, I want calibration saved across sessions, so that I do not repeat setup every lecture.

22. As a student who moved monitors or webcam, I want **Recalibrate** in the menu, so that mapping stays accurate without reinstalling.

23. As a student, I want on-display attention inferred from model pitch (not face size), so that looking away is detected more reliably.

24. As a student, I want built-in webcam frames mirrored consistently and external desk cams unmirrored, with no flip mid-session, so that calibration and gaze mapping stay stable.

25. As a student, I want the default system webcam (built-in or USB desk cam), so that I do not need special hardware.

26. As a student debugging bad switches, I want recent gaze/focus log lines in the menu and Console.app logs, so that I can see dwell, mapped display, and activation events.

27. As a student, I want stable frames before dwell starts, so that brief pose noise does not trigger a switch.

28. As a developer, I want optional sparse debug frame capture for tuning, so that I can improve mapping without affecting live latency.

### Scope and success (unchanged constraints)

29. As a student, I want display-level focus only (not window-level gaze), so that the MVP stays shippable.

30. As a student, I want no dedicated eye-tracking hardware, cloud, Flutter UI, or login-item auto-start for this MVP.

31. As a student, I want last-focused apps remembered only for the current session, not across reboots.

32. As a student, I want low battery impact via low frame-rate inference in memory, so that a full lecture on laptop power is feasible.

33. As a student, I want to complete one 30+ minute real study session as the definition of done, so that success is workflow-based.

34. As a student, I want to use gaze pause at most occasionally during that session, so that the product is usable with a safety net.

35. As a student, I want to rarely need Command+Tab to correct focus during that session, so that the value proposition holds.

36. As a maintainer, I want domain terms in CONTEXT.md aligned with this PRD, so that future work shares one vocabulary.

37. As a maintainer, I want post-MVP items (third display, hardware eye tracker, full calibration wizard, window-level gaze) deferred until **MVP success**, so that scope does not creep.

## Implementation Decisions

### Guiding principle

**MVP simplicity** from CONTEXT.md: smallest behavior set that proves the study workflow. The pivot replaces the **Gaze stream** signal only; **Dwell**, **Focus lock**, **Focus history**, **Focus activation**, **Menu bar control**, **Gaze pause**, and **Dual-display mode** stay as implemented unless a gaze issue explicitly updates them.

### Already implemented (baseline — do not rebuild)

| Area | Status |
|------|--------|
| Swift package, menu bar agent, session start/stop | Done |
| Dual-display detection and display numbering | Done |
| GazeStateMachine (dwell ~0.9 s, 4 stable frames, focus lock, fixed yaw threshold) | Done — **must accept calibrated thresholds** |
| FocusHistory, FocusController, FocusObserver, Accessibility activation | Done |
| Gaze pause hotkey, menu bar status (D1/D2, app name, gaze status, log lines) | Done |
| EyeWindowLog | Done |
| HeadPoseEngine (webcam + Vision face rects + heuristic mapper) | Done — **to be replaced by gaze model pipeline** |

### To build or replace (gaze pivot)

| Module | Responsibility |
|--------|----------------|
| **Gaze model artifact** | Ship pre-converted Core ML (`.mlpackage`) derived from `models/mobilenetv2_gaze.onnx`; conversion is a one-time dev/build step, not at app runtime. |
| **GazeEngine** (replaces heuristic **HeadPoseEngine** inference path) | Webcam capture, fixed **Camera mirroring**, Vision face rectangles, face crop preprocess, Core ML inference → yaw/pitch; derive **On-display attention** from pitch; expose `GazeSample` stream at low FPS in memory. |
| **CalibrationStore** | Persist left/right yaw thresholds (and optional center) from D1/D2 steps; load on session start. |
| **Calibration flow** | Menu-driven: on first session without store, block gaze switching until D1 then D2 samples collected; **Recalibrate** clears and reruns. |
| **CalibratedGazeMapping** | **GazeStateMachine** (or mapper) uses stored thresholds instead of global `yawThresholdRadians` alone. |
| **SessionCoordinator** | Wire **GazeEngine** + calibration gate + existing state machine and focus path. |

**Technology**

- Core ML for **Gaze estimation model** inference; Vision for face detection only.
- No Python or ONNX runtime in the shipping app.
- Preprocess face crop to match MobileGaze training expectations (document input size/normalization in issue notes).

**Parameters (retain unless calibration supersedes)**

- Medium dwell ~0.9 s; 4 stable frames at ~5 FPS before dwell timer.
- Focus lock unchanged.
- Global yaw threshold remains fallback until calibration exists.

**Permissions UX**

- Unchanged: Camera + Accessibility on first use; menu shows blocked states.

### Out of scope for this PRD

- Retraining or fine-tuning the gaze model on device
- Window- or region-level gaze
- Three+ display switching (warn/disable only)
- Dedicated eye-tracking hardware
- Cloud inference or frame upload
- Flutter / web control plane
- Login item auto-start
- Persisting last-focused apps across sessions
- Cmd+Tab suppression window
- User-configurable dwell or pause chord in UI
- ONNX inference at runtime in Swift

## Testing Decisions

**Good tests**: Observable inputs/outputs at module boundaries; no real webcam, Core ML, or Accessibility in unit tests.

| Module | Test approach |
|--------|----------------|
| **GazeStateMachine** | Keep self-check: dwell, lock, attention gating; add cases for **calibrated** left/right thresholds. |
| **CalibrationStore** / mapper | Pure tests: given recorded D1/D2 yaw samples → expected thresholds → correct display mapping. |
| **DisplayMonitor**, **FocusHistory** | Existing patterns; unchanged. |
| **GazeEngine**, **FocusController** | Manual on hardware with Camera + Accessibility; smoke test that session starts and menu shows gaze status. |

**MVP success test (manual)**: `issues/MVP-SESSION-CHECKLIST.md` — 30+ minute dual-display session after gaze model + calibration are integrated; note pause and Command+Tab frequency.

## Out of Scope

- Vision-only head pose as the primary gaze signal (replaced)
- Per-user model training
- Window-level focus
- Third+ display switching
- Eye tracker hardware
- Network APIs
- Login item
- Cross-session last-focused persistence
- Runtime ONNX in the app

## Further Notes

- Domain glossary: `CONTEXT.md` (gaze model, calibration heuristics, webcam, camera mirroring).
- Upstream model: [yakhyo/gaze-estimation](https://github.com/yakhyo/gaze-estimation) MobileNetV2; weights in `models/mobilenetv2_gaze.onnx`.
- Issues `000`–`008` in `issues/done/` delivered the heuristic MVP shell; issues `011+` deliver the gaze pivot.
- Issue `009` (debug capture) applies to the new gaze pipeline, not head-pose heuristics.
- Issue `010` (MVP readiness) completes after gaze integration and a real hardware session.
