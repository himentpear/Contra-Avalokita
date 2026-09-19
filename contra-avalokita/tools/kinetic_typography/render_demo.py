"""Render the six-second glyph loop and its synchronized algorithm view.

Requires Pillow. Reference states supply individual glyph cells and the seal;
each displayed frame is assembled here by the timeline and grid rules.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
ATLAS_PATH = ROOT / "assets/kinetic_typography/glyph_atlas.png"
SEED_PATH = ROOT / "assets/kinetic_typography/seed.png"
SEALS_PATH = ROOT / "assets/kinetic_typography/seal_states.png"
STATES_PATH = ROOT / "assets/kinetic_typography/glyph_states.png"
OPENING_PATH = ROOT / "assets/kinetic_typography/opening_states.png"
CYCLE_PATH = ROOT / "assets/kinetic_typography/glyph_cycle.png"
ACTIVE_INDEX_PATH = ROOT / "assets/kinetic_typography/state_active_index.png"
CLOCK_PATH = ROOT / "assets/kinetic_typography/glyph_clock.png"
WHITE_CELLS_PATH = ROOT / "assets/kinetic_typography/white_edge_cells.png"
WHITE_INDEX_PATH = ROOT / "assets/kinetic_typography/white_edge_index.png"
OUTPUT = ROOT / "artifacts/kinetic_typography/glyph_generation_iteration.gif"
SIDE = 720
GRID = 13
TILE = 55
PITCH = 55
STATE_TIMES = (0.5, 1.0, 1.5, 2.0, 2.5, 2.9, 3.2, 3.5, 3.8,
               4.2, 4.5, 4.8, 4.9, 5.0, 5.1, 5.2, 5.3, 5.5)
STATE_COLUMNS = 3
GLYPH_HZ = 30
OPENING_FRAMES = 16
CYCLE_FRAMES = 16
SEAL_TIMES = STATE_TIMES[9:]
RED = (202, 34, 42)
WHITE = (245, 244, 239)
BLACK = (0, 0, 0)


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in ("C:/Windows/Fonts/consola.ttf",
                 "C:/Windows/Fonts/arial.ttf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"):
        if Path(name).exists():
            return ImageFont.truetype(name, size)
    return ImageFont.load_default()


def birth_time(x: int, y: int) -> float:
    """Three vertical seeds feed the same Manhattan-distance wave."""
    vertical = min(abs(y - 6) * .25, y * .25 + .25,
                   (12 - y) * .25 + .25)
    return abs(x - 6) * .25 + vertical


def portal_front(t: float, y: int) -> float:
    """The center opens first; the hole narrows towards the top/bottom."""
    return 4.6 * (t - 4.0) - .35 * abs(y - 6)


def cell_state(t: float, x: int, y: int) -> str:
    born = birth_time(x, y)
    if t + 1e-4 < born:
        return "off"
    if t < 3.95:
        return "white" if t - born < .19 else "red"
    front = portal_front(t, y)
    distance = abs(x - 6)
    if distance < front:
        return "off"
    if distance < front + 1.2 and (t * 4.0) % 1.0 < .32:
        return "white"
    return "red"


def ease(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def wheel_scale(t: float) -> float:
    if t < 3.75 or t > 5.48:
        return 0.0
    if t < 5.02:
        return ease((t - 3.75) / 1.27)
    return 1.0 - ease((t - 5.02) / .46)


def state_index(t: float) -> int:
    return min(range(len(STATE_TIMES)), key=lambda i: abs(t - STATE_TIMES[i]))


def glyph_tick(t: float) -> int:
    return max(0, min(179, int(t * GLYPH_HZ + 1e-5)))


def cycle_index(phase_tick: int, x: int, y: int) -> int:
    return (phase_tick + x * 5 + y * 3) % CYCLE_FRAMES


def sheet_tiles(path: Path, frames: int) -> list[list[Image.Image]]:
    sheet = Image.open(path).convert("RGBA")
    expected = (4 * GRID * TILE, 4 * GRID * TILE)
    if sheet.size != expected:
        raise ValueError(f"{path.name} must be {expected[0]} x {expected[1]}")
    result = []
    for frame in range(frames):
        cells = []
        for y in range(GRID):
            for x in range(GRID):
                source_x = ((frame % 4) * GRID + x) * TILE
                source_y = ((frame // 4) * GRID + y) * TILE
                cells.append(sheet.crop((source_x, source_y,
                                         source_x + TILE, source_y + TILE)))
        result.append(cells)
    return result


class GlyphLoop:
    def __init__(self) -> None:
        if not ATLAS_PATH.exists() or not SEED_PATH.exists():
            raise FileNotFoundError("Extract the atlas first; see README.md")
        atlas = Image.open(ATLAS_PATH).convert("RGBA")
        if atlas.size != (GRID * TILE, GRID * TILE):
            raise ValueError(f"Atlas must be {GRID * TILE} x {GRID * TILE}")
        states = Image.open(STATES_PATH).convert("RGBA")
        expected = (STATE_COLUMNS * GRID * TILE,
                    ((len(STATE_TIMES) + STATE_COLUMNS - 1) // STATE_COLUMNS)
                    * GRID * TILE)
        if states.size != expected:
            raise ValueError(f"States sheet must be {expected[0]} x {expected[1]}")
        self.tiles: list[list[Image.Image]] = []
        for frame_index in range(len(STATE_TIMES)):
            cells: list[Image.Image] = []
            for y in range(GRID):
                for x in range(GRID):
                    source_x = ((frame_index % STATE_COLUMNS) * GRID + x) * TILE
                    source_y = ((frame_index // STATE_COLUMNS) * GRID + y) * TILE
                    box = (source_x, source_y, source_x + TILE,
                           source_y + TILE)
                    cells.append(states.crop(box))
            self.tiles.append(cells)
        self.opening = sheet_tiles(OPENING_PATH, OPENING_FRAMES)
        self.cycle = sheet_tiles(CYCLE_PATH, CYCLE_FRAMES)
        self.active_index = Image.open(ACTIVE_INDEX_PATH).convert("L")
        if self.active_index.size != (GRID, len(STATE_TIMES) * GRID):
            raise ValueError("State active index must be 13 x 234")
        self.clock = Image.open(CLOCK_PATH).convert("L")
        if self.clock.size != (1, 180):
            raise ValueError("Glyph clock must be 1 x 180")
        self.white_index = Image.open(WHITE_INDEX_PATH).convert("RGB")
        if self.white_index.size != (GRID, 180 * GRID):
            raise ValueError("White edge index must be 13 x 2340")
        white_atlas = Image.open(WHITE_CELLS_PATH).convert("RGBA")
        if white_atlas.width != 32 * TILE or white_atlas.height % TILE:
            raise ValueError("White edge cell atlas has invalid dimensions")
        self.white_cells = [white_atlas.crop(((i % 32) * TILE,
                                             (i // 32) * TILE,
                                             (i % 32 + 1) * TILE,
                                             (i // 32 + 1) * TILE))
                            for i in range(32 * (white_atlas.height // TILE))]
        self.tile_states: list[list[str]] = []
        for cells in self.tiles:
            occupancy: list[str] = []
            for tile in cells:
                extrema = tile.getextrema()
                if max(channel[1] for channel in extrema[:3]) <= 80:
                    occupancy.append("off")
                elif extrema[1][1] > 130 and extrema[2][1] > 130:
                    occupancy.append("white")
                else:
                    occupancy.append("red")
            self.tile_states.append(occupancy)
        self.seed = Image.open(SEED_PATH).convert("RGBA")
        seals = Image.open(SEALS_PATH).convert("RGBA")
        if seals.size != (1200, 1200):
            raise ValueError("Seal states sheet must be 1200 x 1200")
        self.seals = [seals.crop(((i % 3) * 400, (i // 3) * 400,
                                  (i % 3 + 1) * 400, (i // 3 + 1) * 400))
                      for i in range(len(SEAL_TIMES))]
        self.font_sm = font(15)
        self.font_md = font(19)
        self.font_lg = font(28)

    def white_override_index(self, t: float, x: int, y: int) -> int:
        frame = glyph_tick(t)
        low, high, _ = self.white_index.getpixel((x, frame * GRID + y))
        return low + 256 * high - 1

    def left(self, t: float) -> Image.Image:
        output = Image.new("RGBA", (SIDE, SIDE), BLACK + (255,))
        tick = glyph_tick(t)
        if tick < OPENING_FRAMES:
            for y in range(GRID):
                for x in range(GRID):
                    output.alpha_composite(
                        self.opening[tick][y * GRID + x],
                        (360 + (x - 6) * PITCH - 27,
                         360 + (y - 6) * PITCH - 27))
            return output
        index = state_index(t)
        phase_tick = self.clock.getpixel((0, tick))
        for y in range(GRID):
            for x in range(GRID):
                state = cell_state(t, x, y)
                white_index = self.white_override_index(t, x, y)
                if state == "off" and t < 4.0 and white_index < 0:
                    continue
                if (t >= 4.0 and white_index < 0 and
                        self.active_index.getpixel((x, index * GRID + y)) == 0):
                    continue
                tile = (self.white_cells[white_index] if white_index >= 0
                        else self.cycle[cycle_index(phase_tick, x, y)][y * GRID + x])
                output.alpha_composite(tile, (360 + (x - 6) * PITCH - 27,
                                              360 + (y - 6) * PITCH - 27))
        if t >= 4.0:
            seal = self.seals[min(range(len(SEAL_TIMES)),
                                  key=lambda i: abs(t - SEAL_TIMES[i]))]
            output.alpha_composite(seal, (160, 160))
            # The seal state is sampled more sparsely than the white flashes.
            # Reapply frame-exact white cells above it to preserve the edge.
            for y in range(GRID):
                for x in range(GRID):
                    white_index = self.white_override_index(t, x, y)
                    if white_index >= 0:
                        output.alpha_composite(
                            self.white_cells[white_index],
                            (360 + (x - 6) * PITCH - 27,
                             360 + (y - 6) * PITCH - 27))
        return output

    def right(self, t: float) -> Image.Image:
        image = Image.new("RGB", (SIDE, SIDE), (5, 5, 6))
        draw = ImageDraw.Draw(image)
        draw.text((34, 25), "GLYPH GENERATOR", font=self.font_lg, fill=WHITE)
        draw.text((35, 65), "ITERATION  /  00..12", font=self.font_md, fill=RED)
        stage = ("01  SEED" if t < .30 else
                 "02  AXIS" if t < 1.3 else
                 "03  FIELD" if t < 3.9 else
                 "04  VOID + SEAL" if t < 5.5 else "05  RESET")
        draw.text((520, 69), stage, font=self.font_sm, fill=WHITE)

        origin_x, origin_y, step = 33, 117, 38
        active = 0
        frontier = 0
        tick = glyph_tick(t)
        phase_tick = self.clock.getpixel((0, tick))
        sampled = self.tile_states[state_index(t)]
        for y in range(GRID):
            for x in range(GRID):
                if tick < OPENING_FRAMES:
                    tile = self.opening[tick][y * GRID + x]
                    extrema = tile.getextrema()
                    state = ("white" if extrema[1][1] > 130 and extrema[2][1] > 130
                             else "red" if extrema[0][1] > 80 else "off")
                else:
                    state = (sampled[y * GRID + x] if t >= 4.0
                             else cell_state(t, x, y))
                white_index = self.white_override_index(t, x, y)
                if white_index >= 0:
                    state = "white"
                elif state != "off":
                    state = "red"
                left = origin_x + x * step
                top = origin_y + y * step
                draw.rectangle((left, top, left + step - 2, top + step - 2),
                               fill=(16, 16, 18), outline=(40, 39, 42), width=1)
                if state == "off":
                    continue
                active += 1
                if state == "white":
                    frontier += 1
                color = WHITE if state == "white" else RED
                draw.rectangle((left + 10, top + 10, left + step - 12,
                                top + step - 12), fill=color)
                if state == "white":
                    draw.rectangle((left + 5, top + 5, left + step - 7,
                                    top + step - 7), outline=color, width=1)
        if wheel_scale(t) > .05:
            radius = round(83 * wheel_scale(t))
            cx = origin_x + 6 * step + step // 2
            cy = origin_y + 6 * step + step // 2
            draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius),
                         outline=RED, width=2)

        tx = 550
        draw.text((tx, 125), "ACTIVE", font=self.font_sm, fill=(150, 145, 145))
        draw.text((tx, 147), f"{active:03d} / 169", font=self.font_md, fill=WHITE)
        draw.text((tx, 194), "FRONTIER", font=self.font_sm, fill=(150, 145, 145))
        draw.text((tx, 216), f"{frontier:03d} cells", font=self.font_md, fill=WHITE)
        draw.text((tx, 263), "CELL", font=self.font_sm, fill=(150, 145, 145))
        draw.text((tx, 285), "55 x 55", font=self.font_md, fill=WHITE)
        draw.text((tx, 333), "PITCH", font=self.font_sm, fill=(150, 145, 145))
        draw.text((tx, 355), "55 px", font=self.font_md, fill=WHITE)
        draw.text((tx, 405), "UNIT GLYPH", font=self.font_sm, fill=(150, 145, 145))
        draw.rectangle((tx, 430, tx + 122, 552), outline=(70, 45, 47), width=1)
        glyph_index = min(12, round((t % 3.0) / 3.0 * 12))
        selected_state = state_index(t)
        selected_cell = 6 * GRID + glyph_index
        if self.tile_states[selected_state][selected_cell] == "off":
            selected_cell = min(
                (i for i, status in enumerate(self.tile_states[selected_state])
                 if status != "off"),
                key=lambda i: abs(i // GRID - 6) + abs(i % GRID - glyph_index),
                default=selected_cell)
        unit = (self.opening[tick][6 * GRID + 6]
                if tick < OPENING_FRAMES else
                self.cycle[cycle_index(phase_tick, selected_cell % GRID,
                                       selected_cell // GRID)][selected_cell])
        # Revealing the alpha mask documents construction of a single symbol.
        reveal = round(TILE * ((t * 4.0) % 1.0))
        unit = unit.copy()
        alpha = unit.getchannel("A")
        draw_alpha = ImageDraw.Draw(alpha)
        draw_alpha.rectangle((reveal, 0, TILE, TILE), fill=0)
        unit.putalpha(alpha)
        unit = unit.resize((108, 108), Image.Resampling.NEAREST)
        image.paste(unit, (tx + 7, 437), unit)

        draw.line((33, 632, 688, 632), fill=(75, 43, 46), width=1)
        draw.text((33, 645), "birth = |x| + min(|y - seed|)",
                  font=self.font_sm, fill=(189, 185, 181))
        draw.text((33, 672), f"t = {t:04.2f}s   tick {tick:03d} / 30 Hz",
                  font=self.font_sm, fill=RED)
        return image

    def frame(self, t: float) -> Image.Image:
        output = Image.new("RGB", (SIDE * 2, SIDE), BLACK)
        output.paste(self.left(t).convert("RGB"), (0, 0))
        output.paste(self.right(t), (SIDE, 0))
        return output


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--still", type=float, default=None,
                        help="Render one PNG at this point in the loop")
    args = parser.parse_args()
    if args.fps < 1 or args.fps > 30:
        parser.error("--fps must be between 1 and 30")
    loop = GlyphLoop()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.still is not None:
        loop.frame(args.still).save(args.output)
        return
    frames = [loop.frame(i / args.fps).quantize(colors=32,
               method=Image.Quantize.FASTOCTREE) for i in range(6 * args.fps)]
    # GIF delays have 10 ms precision. Distribute 30/40 ms intervals so the
    # 180 displayed samples still cover precisely six seconds.
    delays = [round((i + 1) * 6000 / len(frames) / 10) * 10 -
              round(i * 6000 / len(frames) / 10) * 10
              for i in range(len(frames))]
    frames[0].save(args.output, save_all=True, append_images=frames[1:],
                   duration=delays, loop=0,
                   optimize=True, disposal=2)
    print(f"Saved {len(frames)} frames to {args.output}")


if __name__ == "__main__":
    main()
