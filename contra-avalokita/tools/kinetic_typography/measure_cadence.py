"""Measure visible center-glyph changes in frames 0..15 of the reference."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("video", type=Path)
    parser.add_argument("--contact", type=Path, default=Path(
        "artifacts/kinetic_typography/first_half_second.png"))
    parser.add_argument("--csv", type=Path, default=Path(
        "artifacts/kinetic_typography/first_half_second_cadence.csv"))
    args = parser.parse_args()
    capture = cv2.VideoCapture(str(args.video))
    fps = capture.get(cv2.CAP_PROP_FPS)
    if not capture.isOpened() or abs(fps - 30.0) > 0.1:
        raise ValueError("Expected the supplied 30 fps reference video")
    masks = []
    frames = []
    for index in range(16):
        ok, bgr = capture.read()
        if not ok:
            raise ValueError("The reference must have at least 16 frames")
        crop = cv2.cvtColor(bgr[333:388, 333:388], cv2.COLOR_BGR2RGB)
        frames.append(crop)
        masks.append(np.max(crop, axis=2) > 70)
    capture.release()

    args.contact.parent.mkdir(parents=True, exist_ok=True)
    contact = Image.new("RGB", (8 * 150, 2 * 118), (15, 15, 17))
    draw = ImageDraw.Draw(contact)
    rows = []
    for index, (crop, mask) in enumerate(zip(frames, masks)):
        change = None
        if index:
            previous = masks[index - 1]
            change = 1.0 - np.count_nonzero(mask & previous) / max(
                1, np.count_nonzero(mask | previous))
        rows.append((index, index / fps, change))
        x, y = (index % 8) * 150, (index // 8) * 118
        draw.text((x + 4, y + 3), f"{index:02d} {index / fps:.3f}s",
                  fill=(230, 230, 230))
        tile = Image.fromarray(crop).resize((88, 88), Image.Resampling.NEAREST)
        contact.paste(tile, (x + 31, y + 24))
    contact.save(args.contact)
    with args.csv.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(("frame", "time_seconds", "change_1_minus_iou"))
        for index, seconds, change in rows:
            writer.writerow((index, f"{seconds:.6f}",
                             "" if change is None else f"{change:.6f}"))
    changed = sum(change is not None and change > .1 for _, _, change in rows)
    print(f"{changed}/15 adjacent pairs change visibly; observed tick = 1/{fps:g} s")


if __name__ == "__main__":
    main()
