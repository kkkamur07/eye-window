# Gaze model I/O (MobileNetV2 / MobileGaze)

Source ONNX: `mobilenetv2_gaze.onnx` ([yakhyo/gaze-estimation](https://github.com/yakhyo/gaze-estimation)).  
Shipped Core ML: `MobileNetV2Gaze.mlpackage` (also linked from `Sources/EyeWindowCore/Resources/GazeModel/` for SPM).

## Input

| Name | Shape | Dtype | Preprocessing |
|------|-------|-------|----------------|
| `input` | `1 × 3 × 448 × 448` | `float32` | Face crop → RGB → resize 448×448 → scale pixels to `[0, 1]` → subtract mean / divide std |

**Mean (RGB):** `[0.485, 0.456, 0.406]`  
**Std (RGB):** `[0.229, 0.224, 0.225]`

Layout is **NCHW** (batch, channels, height, width). BGR sources must convert to RGB before normalization.

## Outputs (logits)

| Name | Shape | Dtype | Meaning |
|------|-------|-------|---------|
| `yaw` | `1 × 90` | `float32` | Horizontal gaze logits (90 bins) |
| `pitch` | `1 × 90` | `float32` | Vertical gaze logits (90 bins) |

## Decode to radians (issue 012)

1. Softmax each 90-bin vector along the bin axis.
2. Bin index tensor: `0 … 89` (float).
3. Degrees: `sum(probs * idx) * 4 - 180` (bin width 4°, offset 180°).
4. Radians: `degrees * π / 180`.

**On-display attention** uses **pitch** (not face-size heuristics): attentive when `pitchAttentionMinRadians < pitch < pitchAttentionMaxRadians` in `GazeInference` (`-0.52` … `+0.26` rad by default).

Swift constants: `GazeModelIO` in `Sources/EyeWindowCore/GazeModelLoader.swift`.

**Runtime load:** `GazeModelLoader` compiles the `.mlpackage` with `MLModel.compileModel(at:)` on first load (Core ML requires compiled `.mlmodelc` for inference).

## Regenerate Core ML

```bash
python3 scripts/convert_gaze_model.py
```

Uses an isolated `.venv-convert` (created on first run). Re-run after updating the ONNX file.
