---
id: "011"
title: "coreml-gaze-model"
type: AFK
status: done
blocked_by: []
parent_prd: "issues/prd.md"
---

## Parent PRD

`issues/prd.md` — **Gaze model artifact**; Core ML from `models/mobilenetv2_gaze.onnx`.

## What to build

One-time conversion of MobileNetV2 gaze ONNX to Core ML (`.mlpackage` or `.mlmodelc`). Check converted artifact into the repo (e.g. `Resources/GazeModel/`). Document conversion command for maintainers. Wire Swift Package / app bundle so `EyeWindowCore` can load the model at runtime. No Python or convert-on-launch in the shipping app.

## Acceptance criteria

- [x] Converted Core ML model present beside ONNX source; README or dev note documents how to regenerate
- [x] `swift build` succeeds with model resource copied into app bundle (or documented copy step)
- [x] Smoke: load model in a minimal Swift snippet or self-check without crashing
- [x] Input/output tensor names and shapes documented for inference issue

## Blocked by

None — can start immediately.

## User stories addressed

- User story 19
- User story 14

## Deliverables

| Artifact | Path |
|----------|------|
| ONNX source | `models/mobilenetv2_gaze.onnx` |
| Core ML bundle | `models/MobileNetV2Gaze.mlpackage` |
| SPM resource copy | `Sources/EyeWindowCore/Resources/GazeModel/MobileNetV2Gaze.mlpackage` |
| I/O spec | `models/GAZE_MODEL_IO.md`, `GazeModelIO` in `GazeModelLoader.swift` |
| Conversion script | `scripts/convert_gaze_model.py` |

**Regenerate:** `python3 scripts/convert_gaze_model.py` (creates `.venv-convert`, writes `models/`, copies into SPM resources).

**Load API:** `GazeModelLoader.loadModel()` — compiles `.mlpackage` via `MLModel.compileModel(at:)` then loads (no ONNX runtime in app).
