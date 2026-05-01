"""Convert a unitree_rl_mjlab style PM01 motion NPZ to the engineai_amp schema.

The unitree PM01 model has 24 joints and 25 bodies (it includes a head_yaw
joint and a head body). engineai_amp's PM01 model has 23 joints and 24 bodies.
This utility drops the trailing head joint/body and casts ``fps`` to int64 so
the output file matches the engineai_amp shipped reference.

Usage:
    python scripts/convert_npz.py <src.npz> <dst.npz>
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

JOINT_DIM_TARGET = 23
BODY_DIM_TARGET = 24
BODY_KEYS = ("body_pos_w", "body_quat_w", "body_lin_vel_w", "body_ang_vel_w")


def convert(src: Path, dst: Path) -> None:
    data = dict(np.load(src, allow_pickle=True))

    jp = data["joint_pos"]
    if jp.shape[1] == JOINT_DIM_TARGET:
        print(f"  joints already {JOINT_DIM_TARGET}-DOF, no trim")
    elif jp.shape[1] == JOINT_DIM_TARGET + 1:
        print(f"  trimming joints {jp.shape[1]} -> {JOINT_DIM_TARGET} (drop head_yaw)")
        data["joint_pos"] = jp[:, :JOINT_DIM_TARGET].astype(np.float32)
        data["joint_vel"] = data["joint_vel"][:, :JOINT_DIM_TARGET].astype(np.float32)
    else:
        raise SystemExit(
            f"unexpected joint dim {jp.shape[1]}, expected {JOINT_DIM_TARGET} or {JOINT_DIM_TARGET + 1}"
        )

    for k in BODY_KEYS:
        if k not in data:
            continue
        b = data[k]
        if b.shape[1] == BODY_DIM_TARGET:
            continue
        if b.shape[1] == BODY_DIM_TARGET + 1:
            data[k] = b[:, :BODY_DIM_TARGET].astype(np.float32)
        else:
            raise SystemExit(f"unexpected body dim {b.shape[1]} on {k}")

    data["fps"] = np.asarray(data["fps"], dtype=np.int64)

    dst.parent.mkdir(parents=True, exist_ok=True)
    np.savez(dst, **data)

    n = data["joint_pos"].shape[0]
    fps = int(data["fps"][0])
    print(f"  wrote {dst}")
    print(f"  joint_pos shape={data['joint_pos'].shape}, frames={n}, fps={fps}, duration={n / fps:.2f}s")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("src", type=Path, help="source .npz (e.g. unitree-style 24-DOF PM01)")
    parser.add_argument("dst", type=Path, help="destination .npz inside dataset/data/")
    args = parser.parse_args()

    print(f"converting {args.src} -> {args.dst}")
    convert(args.src, args.dst)


if __name__ == "__main__":
    main()
