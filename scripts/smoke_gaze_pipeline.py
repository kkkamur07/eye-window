#!/usr/bin/env python3
"""Smoke test: ONNX gaze decode + gaze vector (compare with Swift GazeSmokeTest).

Uses the same decode as yakhyo/gaze-estimation onnx_inference.py:
  degrees = sum(softmax(logits) * bin_index) * 4 - 180
  radians = degrees * pi / 180

Gaze vector (matches Swift GazeFeatureVector.fromGaze):
  gx = cos(pitch) * sin(yaw)
  gy = sin(pitch)
  gz = cos(pitch) * cos(yaw)
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
import onnxruntime as ort

REPO = Path(__file__).resolve().parents[1]
ONNX_PATH = REPO / "models" / "mobilenetv2_gaze.onnx"
BINS = 90
BIN_WIDTH = 4
ANGLE_OFFSET = 180
MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def softmax(x: np.ndarray) -> np.ndarray:
    e = np.exp(x - np.max(x))
    return e / e.sum()


def decode_degrees(logits: np.ndarray) -> float:
    probs = softmax(logits.reshape(-1))
    idx = np.arange(BINS, dtype=np.float32)
    return float((probs * idx).sum() * BIN_WIDTH - ANGLE_OFFSET)


def decode_radians(logits: np.ndarray) -> float:
    return math.radians(decode_degrees(logits))


def gaze_vector(yaw_rad: float, pitch_rad: float) -> tuple[float, float, float]:
    cp, sp = math.cos(pitch_rad), math.sin(pitch_rad)
    sy, cy = math.sin(yaw_rad), math.cos(yaw_rad)
    return cp * sy, sp, cp * cy


def peak_logits(bin_index: int, sharpness: float = 20.0) -> np.ndarray:
    logits = np.full(BINS, -sharpness, dtype=np.float32)
    logits[bin_index] = sharpness
    return logits


def uniform_gray_input(gray: int = 128) -> np.ndarray:
    """NCHW float32, same as Swift GazePipelineSmoke.makeUniformGrayInput."""
    rgb = np.full((448, 448, 3), gray, dtype=np.uint8)
    x = rgb.astype(np.float32) / 255.0
    x = (x - MEAN) / STD
    x = np.transpose(x, (2, 0, 1))
    return np.expand_dims(x, axis=0)


def test_decode_formula() -> None:
    cases = [(0, -180.0), (45, 0.0), (67, 88.0), (22, -92.0)]
    for bin_idx, expected_deg in cases:
        got = decode_degrees(peak_logits(bin_idx))
        if abs(got - expected_deg) > 0.5:
            raise SystemExit(f"decode bin {bin_idx}: expected {expected_deg}° got {got}°")
    print("  decode formula (peak bins): OK")


def test_gaze_vector_math() -> None:
    yaw, pitch = 0.0, 0.0
    gx, gy, gz = gaze_vector(yaw, pitch)
    if abs(gx) > 1e-6 or abs(gy) > 1e-6 or abs(gz - 1.0) > 1e-6:
        raise SystemExit(f"forward gaze vector wrong: ({gx},{gy},{gz})")
    yaw = math.radians(30)
    gx, gy, gz = gaze_vector(yaw, 0.0)
    length = math.sqrt(gx * gx + gy * gy + gz * gz)
    if abs(length - 1.0) > 1e-6:
        raise SystemExit(f"unit length failed: {length}")
    print("  gaze vector math: OK")


def run_onnx_uniform_gray() -> tuple[float, float, float, float, float]:
    if not ONNX_PATH.is_file():
        raise SystemExit(f"ONNX not found: {ONNX_PATH}")
    session = ort.InferenceSession(str(ONNX_PATH), providers=["CPUExecutionProvider"])
    inp = uniform_gray_input()
    yaw_logits, pitch_logits = session.run(None, {"input": inp})
    yaw_rad = decode_radians(yaw_logits)
    pitch_rad = decode_radians(pitch_logits)
    gx, gy, gz = gaze_vector(yaw_rad, pitch_rad)
    return yaw_rad, pitch_rad, gx, gy, gz


def main() -> None:
    print("Gaze pipeline smoke (Python / ONNX)")
    test_decode_formula()
    test_gaze_vector_math()
    yaw, pitch, gx, gy, gz = run_onnx_uniform_gray()
    print(f"  ONNX uniform-gray inference:")
    print(f"    yaw  = {yaw:.4f} rad ({math.degrees(yaw):.2f}°)")
    print(f"    pitch= {pitch:.4f} rad ({math.degrees(pitch):.2f}°)")
    print(f"    vector gx={gx:.4f} gy={gy:.4f} gz={gz:.4f}")
    print("PASS — compare these values with: swift run GazeSmokeTest")


if __name__ == "__main__":
    main()
