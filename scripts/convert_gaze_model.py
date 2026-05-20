#!/usr/bin/env python3
"""One-time ONNX → Core ML conversion for MobileNetV2 gaze (issue 011).

Requires the conversion venv (see README). Writes models/MobileNetV2Gaze.mlpackage
and refreshes the SPM resource symlink under Sources/EyeWindowCore/Resources/GazeModel/.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
ONNX_PATH = REPO_ROOT / "models" / "mobilenetv2_gaze.onnx"
MLPACKAGE_PATH = REPO_ROOT / "models" / "MobileNetV2Gaze.mlpackage"
RESOURCE_LINK = (
    REPO_ROOT / "Sources" / "EyeWindowCore" / "Resources" / "GazeModel" / "MobileNetV2Gaze.mlpackage"
)
VENV_PYTHON = REPO_ROOT / ".venv-convert" / "bin" / "python3"

CONVERT_BODY = r'''
import onnx
import torch
import torch.nn as nn
import coremltools as ct
from onnx2torch import convert as onnx2torch_convert
from onnxslim import slim


class GazeWrapper(nn.Module):
    def __init__(self, inner: nn.Module) -> None:
        super().__init__()
        self.inner = inner

    def forward(self, x: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        return self.inner(x)


onnx_path = {onnx_path!r}
out_path = {out_path!r}

slim_model = slim(onnx.load(onnx_path))
inner = onnx2torch_convert(slim_model)
inner.eval()
model = GazeWrapper(inner)
model.eval()

example = torch.randn(1, 3, 448, 448)
traced = torch.jit.trace(model, example, strict=False)

mlmodel = ct.convert(
    traced,
    inputs=[ct.TensorType(name="input", shape=example.shape)],
    outputs=[ct.TensorType(name="yaw"), ct.TensorType(name="pitch")],
    convert_to="mlprogram",
    minimum_deployment_target=ct.target.macOS13,
    compute_precision=ct.precision.FLOAT32,
)

if out_path.exists():
    shutil.rmtree(out_path)
mlmodel.save(out_path)

spec = mlmodel.get_spec()
inputs = [(i.name, list(i.type.multiArrayType.shape)) for i in spec.description.input]
outputs = [(o.name, list(o.type.multiArrayType.shape)) for o in spec.description.output]
print("inputs:", inputs)
print("outputs:", outputs)
'''


def ensure_venv() -> Path:
    if not VENV_PYTHON.is_file():
        print("Creating .venv-convert …", file=sys.stderr)
        subprocess.check_call([sys.executable, "-m", "venv", str(REPO_ROOT / ".venv-convert")])
        pip = REPO_ROOT / ".venv-convert" / "bin" / "pip"
        subprocess.check_call(
            [
                str(pip),
                "install",
                "coremltools==8.2",
                "onnx",
                "onnx2torch",
                "onnxslim",
                "torch==2.2.2",
            ]
        )
    return VENV_PYTHON


def refresh_spm_resource_copy() -> None:
    """Copy into EyeWindowCore resources (SPM does not bundle external symlinks reliably)."""
    RESOURCE_LINK.parent.mkdir(parents=True, exist_ok=True)
    if RESOURCE_LINK.exists():
        shutil.rmtree(RESOURCE_LINK)
    shutil.copytree(MLPACKAGE_PATH, RESOURCE_LINK)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--onnx",
        type=Path,
        default=ONNX_PATH,
        help=f"ONNX source (default: {ONNX_PATH})",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=MLPACKAGE_PATH,
        help=f"Core ML output (default: {MLPACKAGE_PATH})",
    )
    args = parser.parse_args()

    if not args.onnx.is_file():
        sys.exit(f"ONNX model not found: {args.onnx}")

    python = ensure_venv()
    body = CONVERT_BODY.format(onnx_path=str(args.onnx), out_path=str(args.out))
    subprocess.check_call([str(python), "-c", body], cwd=REPO_ROOT)

    refresh_spm_resource_copy()
    print(f"Wrote {args.out}")
    print(f"SPM resource copy: {RESOURCE_LINK}")


if __name__ == "__main__":
    main()
