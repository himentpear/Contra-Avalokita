"""Split a supplied movie into reusable glyph cells and central seal states.

The output is cell-level source material for the Godot component and the GIF
renderer. Layout, activation, timing, and debug iteration remain code-driven.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


GRID = 13
PITCH = 55
TILE = 55
CENTER = 360
STATE_TIMES = (0.5, 1.0, 1.5, 2.0, 2.5, 2.9, 3.2, 3.5, 3.8,
               4.2, 4.5, 4.8, 4.9, 5.0, 5.1, 5.2, 5.3, 5.5)
STATE_COLUMNS = 3
SEAL_RADII = (65, 125, 175, 190, 193, 193, 180, 85, 0)
WHITE_COLUMNS = 32
OPENING_FRAMES = 16
CYCLE_FRAMES = 16
CYCLE_START_FRAME = 90  # 3.0 s: the field is dense, so every cell has a glyph.


def video_frame(path: Path, seconds: float) -> np.ndarray:
    capture = cv2.VideoCapture(str(path))
    if not capture.isOpened():
        raise FileNotFoundError(f"Cannot open reference video: {path}")
    capture.set(cv2.CAP_PROP_POS_MSEC, seconds * 1000)
    ok, frame = capture.read()
    capture.release()
    if not ok or frame.shape[:2] != (720, 720):
        raise ValueError("Expected a readable 720 x 720 reference frame")
    return cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)


def mask_from_red(rgb: np.ndarray) -> np.ndarray:
    # The reference is red ink on black. This retains its soft antialiased edges
    # while removing H.264's low-amplitude dark background noise.
    red = rgb[:, :, 0].astype(np.float32)
    green = rgb[:, :, 1].astype(np.float32)
    blue = rgb[:, :, 2].astype(np.float32)
    signal = np.maximum(red - np.maximum(green, blue) * 0.45 - 5.0, 0.0)
    return np.uint8(np.clip(signal / 178.0 * 255.0, 0.0, 255.0))


def save_white_mask(alpha: np.ndarray, path: Path) -> None:
    image = np.empty((*alpha.shape, 4), dtype=np.uint8)
    image[:, :, :3] = 255
    image[:, :, 3] = alpha
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(image, "RGBA").save(path)


def extract(video: Path, atlas_path: Path, seed_path: Path,
            states_path: Path, white_cells_path: Path,
            white_index_path: Path, seals_path: Path,
            opening_path: Path, cycle_path: Path,
            active_index_path: Path, clock_path: Path) -> None:
    atlas_side = GRID * TILE
    opening = np.zeros((4 * atlas_side, 4 * atlas_side, 4), dtype=np.uint8)
    cycle = np.zeros_like(opening)
    capture = cv2.VideoCapture(str(video))
    for frame_index in range(CYCLE_START_FRAME + CYCLE_FRAMES):
        ok, bgr = capture.read()
        if not ok:
            raise ValueError("Reference video ended during glyph-clock sampling")
        if frame_index >= OPENING_FRAMES and frame_index < CYCLE_START_FRAME:
            continue
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        sheet = opening if frame_index < OPENING_FRAMES else cycle
        block = (frame_index if frame_index < OPENING_FRAMES
                 else frame_index - CYCLE_START_FRAME)
        block_x = (block % 4) * atlas_side
        block_y = (block // 4) * atlas_side
        for row in range(GRID):
            for column in range(GRID):
                x = CENTER + (column - 6) * PITCH
                y = CENTER + (row - 6) * PITCH
                cell = rgb[y - 27 : y + 28, x - 27 : x + 28].copy()
                if sheet is cycle:
                    # Cycle sprites contribute shape only. Color and white
                    # flashes are controlled by the separate timeline layers.
                    strength = mask_from_red(cell)
                    cell = np.uint8(strength[:, :, None] / 255.0 *
                                    np.array([202, 34, 42], dtype=np.float32))
                top = block_y + row * TILE
                left = block_x + column * TILE
                sheet[top : top + TILE, left : left + TILE, :3] = cell
                sheet[top : top + TILE, left : left + TILE, 3] = 255
    capture.release()
    opening_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(opening, "RGBA").save(opening_path)
    Image.fromarray(cycle, "RGBA").save(cycle_path)

    dense = video_frame(video, 3.2)
    atlas = np.zeros((GRID * TILE, GRID * TILE), dtype=np.uint8)
    for row in range(GRID):
        for column in range(GRID):
            x = CENTER + (column - 6) * PITCH
            y = CENTER + (row - 6) * PITCH
            atlas[row * TILE : (row + 1) * TILE,
                  column * TILE : (column + 1) * TILE] = mask_from_red(
                dense[y - 27 : y + 28, x - 27 : x + 28]
            )
    save_white_mask(atlas, atlas_path)

    atlas_side = GRID * TILE
    state_rows = (len(STATE_TIMES) + STATE_COLUMNS - 1) // STATE_COLUMNS
    states = np.zeros((state_rows * atlas_side,
                       STATE_COLUMNS * atlas_side, 4), dtype=np.uint8)
    active_index = np.zeros((len(STATE_TIMES) * GRID, GRID), dtype=np.uint8)
    seals = np.zeros((3 * 400, 3 * 400, 4), dtype=np.uint8)
    for state_index, seconds in enumerate(STATE_TIMES):
        frame = video_frame(video, seconds)
        if seconds >= 4.0:
            # Split the late frames into a central disc and individual cells.
            # This keeps the changing seal and negative space synchronized.
            seal_index = state_index - 9
            radius = SEAL_RADII[seal_index]
            if radius > 0:
                disc = frame[160:560, 160:560]
                dy, dx = np.ogrid[:400, :400]
                within_disc = np.hypot(dx - 200, dy - 200) < radius
                top = (seal_index // 3) * 400
                left = (seal_index % 3) * 400
                seals[top : top + 400, left : left + 400, :3] = disc
                seals[top : top + 400, left : left + 400, 3] = (
                    within_disc.astype(np.uint8) * 255)
                yy, xx = np.ogrid[:720, :720]
                frame[np.hypot(xx - CENTER, yy - CENTER) < radius] = 0
        for row in range(GRID):
            for column in range(GRID):
                x = CENTER + (column - 6) * PITCH
                y = CENTER + (row - 6) * PITCH
                cell = frame[y - 27 : y + 28,
                             x - 27 : x + 28].copy()
                # A cell absent in an early frame borrows the dense atlas so
                # a continuous activation rule can reveal it later.
                if seconds < 4.0 and np.count_nonzero(
                        np.max(cell, axis=2) > 40) < 30:
                    fallback = atlas[row * TILE : (row + 1) * TILE,
                                     column * TILE : (column + 1) * TILE]
                    cell = np.uint8(fallback[:, :, None] / 255.0 *
                                    np.array([202, 34, 42], dtype=np.float32))
                # White flashes are replaced by frame-exact cell overrides.
                # Keep the reusable state atlas red between those flashes.
                pale = ((cell[:, :, 0] > 8)
                        & (cell[:, :, 1] > cell[:, :, 0] * 0.65)
                        & (cell[:, :, 2] > cell[:, :, 0] * 0.65))
                if np.any(pale):
                    brightness = cell[pale, 0].astype(np.float32) / 245.0
                    cell[pale] = np.uint8(np.clip(
                        brightness[:, None]
                        * np.array([202, 34, 42], dtype=np.float32),
                        0, 255))
                top = ((state_index // STATE_COLUMNS) * GRID + row) * TILE
                left = ((state_index % STATE_COLUMNS) * GRID + column) * TILE
                states[top : top + TILE, left : left + TILE, :3] = cell
                states[top : top + TILE, left : left + TILE, 3] = 255
                if np.count_nonzero(np.max(cell, axis=2) > 40) > 5:
                    active_index[state_index * GRID + row, column] = 255
    states_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(states, "RGBA").save(states_path)
    Image.fromarray(active_index, "L").save(active_index_path)
    seals_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(seals, "RGBA").save(seals_path)

    capture = cv2.VideoCapture(str(video))
    index_image = np.zeros((180 * GRID, GRID, 3), dtype=np.uint8)
    clock_image = np.zeros((180, 1), dtype=np.uint8)
    previous_mask: np.ndarray | None = None
    phase_tick = 0
    white_cells: list[np.ndarray] = []
    for frame_index in range(180):
        ok, bgr = capture.read()
        if not ok:
            raise ValueError("Reference video ended before frame 180")
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        current_mask = np.max(rgb, axis=2) > 70
        if previous_mask is not None and np.count_nonzero(
                current_mask ^ previous_mask) > 500:
            phase_tick += 1
        clock_image[frame_index, 0] = phase_tick
        previous_mask = current_mask
        white = np.all(rgb > 130, axis=2)
        for row in range(GRID):
            for column in range(GRID):
                x = CENTER + (column - 6) * PITCH
                y = CENTER + (row - 6) * PITCH
                if np.count_nonzero(white[y - 27 : y + 28,
                                          x - 27 : x + 28]) > 30:
                    cell = rgb[y - 27 : y + 28, x - 27 : x + 28]
                    white_cells.append(cell.copy())
                    encoded = len(white_cells)
                    if encoded > 65535:
                        raise ValueError("Too many white edge cells for index image")
                    index_image[frame_index * GRID + row, column] = (
                        encoded & 255, encoded >> 8, 0)
    capture.release()
    rows = (len(white_cells) + WHITE_COLUMNS - 1) // WHITE_COLUMNS
    white_atlas = np.zeros((rows * TILE, WHITE_COLUMNS * TILE, 4),
                           dtype=np.uint8)
    for sprite_index, cell in enumerate(white_cells):
        top = (sprite_index // WHITE_COLUMNS) * TILE
        left = (sprite_index % WHITE_COLUMNS) * TILE
        white_atlas[top : top + TILE, left : left + TILE, :3] = cell
        white_atlas[top : top + TILE, left : left + TILE, 3] = 255
    white_cells_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(white_atlas, "RGBA").save(white_cells_path)
    white_index_path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(index_image, "RGB").save(white_index_path)
    Image.fromarray(clock_image, "L").save(clock_path)

    opening = video_frame(video, 0.0)
    seed = np.max(opening[CENTER - 24 : CENTER + 25,
                          CENTER - 24 : CENTER + 25], axis=2)
    seed = np.uint8(np.clip((seed.astype(np.float32) - 5.0) * 1.12, 0, 255))
    save_white_mask(seed, seed_path)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("video", type=Path)
    parser.add_argument("--atlas", type=Path,
                        default=Path("assets/kinetic_typography/glyph_atlas.png"))
    parser.add_argument("--seed", type=Path,
                        default=Path("assets/kinetic_typography/seed.png"))
    parser.add_argument("--states", type=Path,
                        default=Path("assets/kinetic_typography/glyph_states.png"))
    parser.add_argument("--white-cells", type=Path,
                        default=Path("assets/kinetic_typography/white_edge_cells.png"))
    parser.add_argument("--white-index", type=Path,
                        default=Path("assets/kinetic_typography/white_edge_index.png"))
    parser.add_argument("--seals", type=Path,
                        default=Path("assets/kinetic_typography/seal_states.png"))
    parser.add_argument("--opening", type=Path,
                        default=Path("assets/kinetic_typography/opening_states.png"))
    parser.add_argument("--cycle", type=Path,
                        default=Path("assets/kinetic_typography/glyph_cycle.png"))
    parser.add_argument("--active-index", type=Path,
                        default=Path("assets/kinetic_typography/state_active_index.png"))
    parser.add_argument("--clock", type=Path,
                        default=Path("assets/kinetic_typography/glyph_clock.png"))
    options = parser.parse_args()
    extract(options.video, options.atlas, options.seed, options.states,
            options.white_cells, options.white_index, options.seals,
            options.opening, options.cycle, options.active_index,
            options.clock)
