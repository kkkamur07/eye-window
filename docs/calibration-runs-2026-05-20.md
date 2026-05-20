# Calibration session analysis (2026-05-20)

Source: `swift run GazeSmokeTest -- --calibrate` (9 runs, ~6 s per dot).

Machine-readable data: [calibration-runs-2026-05-20.csv](calibration-runs-2026-05-20.csv)

## Summary

| Run | Result | Replay | Stable frames (D1/D2) | gx gap | yaw gap (°) | 5D gap | D1 raw std max | D2 raw std max |
|-----|--------|--------|------------------------|--------|-------------|--------|----------------|----------------|
| 1 | PASS | 100% (35/35) | 17 / 18 | 0.124 | 9.27 | 11.29 | 0.353 | 0.061 |
| 2 | **FAIL** | 81% (29/36) | 18 / 18 | 0.068 | 4.50 | 3.33 | 0.337 | 0.087 |
| 3 | PASS | 97% (35/36) | 17 / 19 | 0.037 | 2.34 | 2.79 | 0.379 | 0.062 |
| 4 | **FAIL** | 92% (33/36) | 18 / 18 | 0.097 | 6.49 | 4.97 | 0.353 | 0.088 |
| 5 | **FAIL** | 91% (30/33) | 15 / 18 | 0.020 | 1.72 | 4.63 | 0.332 | 0.048 |
| 6 | PASS | 100% (32/32) | 15 / 17 | 0.011 | 0.39 | 4.36 | 0.320 | 0.048 |
| 7 | PASS | 100% (35/35) | 18 / 17 | 0.040 | 1.98 | 8.14 | 0.226 | 0.046 |
| 8 | PASS | 100% (31/31) | 15 / 16 | 0.015 | 0.60 | — | 0.349 | 0.042 |
| 9 | PASS | 100% (36/36) | 18 / 18 | 0.138 | 9.12 | 6.87 | 0.356 | 0.075 |

**Pass rate:** 6/9 (67%). All failures are replay &lt; 95%, never prototype gap &lt; 0.15.

## Prototype vectors (refined means used at runtime)

```
        gx      gy      gz     yaw    pitch
D1 run2  0.539  -0.199  0.818  0.582  -0.199
D2 run2  0.471  -0.211  0.854  0.504  -0.213   ← FAIL: yaw only ~4.5° apart

D1 run5  0.516  -0.116  0.849  0.546  -0.116
D2 run5  0.535  -0.179  0.824  0.576  -0.180   ← FAIL: gx gap 0.02, yaw 1.7°

D1 run6  0.519  -0.132  0.844  0.552  -0.132
D2 run6  0.508  -0.192  0.839  0.545  -0.194   ← PASS: closest separation (yaw 0.4°)

D1 run9  0.543  -0.155  0.824  0.583  -0.155
D2 run9  0.406  -0.158  0.899  0.424  -0.159   ← PASS: large yaw (9°) + gx (0.14)
```

## Patterns

### 1. Gap metrics do not predict pass/fail by themselves

- **Run 2** failed with 5D gap 3.33 and yaw 4.5° — moderate separation.
- **Run 6** passed with **smallest** yaw gap (0.39°) and gx gap (0.011).
- **Run 3** passed with **smallest** 5D gap (2.79) and yaw 2.3°.

So Mahalanobis “5D gap” and yaw/gx gaps measure **prototype separation**, not **label consistency** during the hold.

### 2. Replay failures ≈ mis-labeled frames during each 6 s window

Replay = each stable frame → 10-frame rolling mean → nearest prototype. Failures mean some D1 frames classified as D2 (or vice versa) **using the means just learned from that same session**.

Typical causes in your logs:

- **Head movement during the 6 s** (high **raw std max** on D1: often 0.32–0.38 while D2 is ~0.04–0.09).
- **Overlap in gaze** between screens (runs 2, 5): prototypes close in yaw/gx.
- **Fewer stable frames** (run 5: 30/33 replay total, 15 stable on D1).

### 3. D1 is noisier than D2 in almost every run

| Run | D1 raw std max | D2 raw std max |
|-----|----------------|----------------|
| 1 | 0.353 | 0.061 |
| 2 | 0.337 | 0.087 |
| 3 | 0.379 | 0.062 |
| … | ~0.32–0.38 | ~0.04–0.09 |

Likely: first dot = settling into calibration, or display 1 is the laptop (webcam geometry differs). Worth noting which physical monitor is D1 vs D2.

### 4. Yaw range across all runs

- Per-step **raw** yaw while recording: ~0.39–0.67 rad (~22–38°) depending on screen.
- **Refined** prototype yaw difference between D1 and D2: **0.4°–9.3°** — huge run-to-run spread for the same hardware.

### 5. What distinguishes FAIL run 2

- D2 prototype yaw **0.504** sits between D1 raw means (~0.36–0.43) and D2 raw (~0.55): boundary-like clustering.
- D2 calibration std on **gx/yaw** elevated (0.060 / 0.069) vs most passes (~0.02 floor).
- 7 misclassified frames out of 36 (81%).

## Practical takeaways

1. **Hold longer and stiller** on each dot (especially **display 1** first) — target D1 raw std max &lt; 0.10 if possible.
2. **Physically exaggerate** look at each screen so gx/yaw means separate (runs 1, 9 with ~9° yaw gap always passed).
3. **Close prototypes can still pass** (run 6) if every stable frame agrees — consistency beats separation.
4. After a PASS, use `--save` once; repeated passes with varying prototypes show session variance, not one fixed “truth.”

## Suggested plots (if you extend this in Python/R)

- Scatter: `d1_proto_yaw` vs `d2_proto_yaw`, color = pass/fail.
- Bar: `replay_pct` vs `d1_raw_std_max`.
- Histogram: `gx_gap` for pass vs fail.
