# Kinetic glyph loop

The supplied 720 × 720, six-second reference was reconstructed as a reusable Godot `Control` and a synchronized comparison GIF. The glyph silhouettes come from individual 55 × 55 cells in the user-supplied movie; the clip itself is not embedded or played. The scene places those cells on a 13 × 13 grid at 55 px intervals.

## Glyph-change cadence

Sampling source frames 0–15 (0.000–0.500 s) gives 15 adjacent-frame comparisons. The center glyph changes visibly in 12 of them (mask change = 1 − intersection-over-union > 0.1). Frames 9→10, 11→12 and 13→14 hold nearly the same shape, while frames 0→9 change on every 1/30-second step. Thus the **observed update clock is 30 Hz**, with occasional repeated glyphs. A 15 Hz clock alone cannot explain the first ten frames. The 30 fps video cannot reveal whether its original generator had a faster internal clock.

The first 16 frames are sampled exactly into a cell sheet. From frame 16 through the late clearing phase, visible cells pick dense-field glyph variants on one shared 30 Hz clock, with a position-dependent phase. A one-pixel-wide clock map records source-wide hold frames, so those ticks keep the current shape. The 18 larger composition keyframes determine which late cells remain visible; 30 fps white-edge overrides and the seal retain their own layers. The variant sequence after the opening is inferred; it is not a frame-perfect reconstruction of the source glyph identities.

## Use in Godot

Open `res://scenes/presentation/kinetic_typography_loop.tscn`, or instantiate it inside another `Control`. It preserves a square canvas inside its available space. `loop_time` seeks to any point in the six-second cycle; set `auto_play` to `false` to drive it from another timeline.

The sequence is deterministic:

1. Three vertically spaced seeds activate cells by Manhattan distance.
2. A 30 Hz clock changes the glyph drawing as the pattern fills and clears. White edge cells are stored separately at 30 fps and replace only the affected glyphs, so the flashes retain their original shape and timing.
3. The full grid holds, then sampled negative-space states open the center.
4. The circle seal changes with the opening, and the remaining edge cells recede.

## Rebuild the assets and GIF

Requires Python, Pillow, and OpenCV for atlas extraction. The renderer itself only needs Pillow.

```powershell
python tools/kinetic_typography/extract_atlas.py "C:\path\to\Kinetic typography coding motion loop.mp4"
python tools/kinetic_typography/measure_cadence.py "C:\path\to\Kinetic typography coding motion loop.mp4"
python tools/kinetic_typography/render_demo.py
```

Output: `artifacts/kinetic_typography/glyph_generation_iteration.gif` (1440 × 720, 30 fps). The left panel shows the generated loop; the right panel shows cell activation, frontier, scale, and the shared glyph tick. The cadence script writes a contact sheet and per-frame change CSV. To render a still for inspection:

```powershell
python tools/kinetic_typography/render_demo.py --still 3.2 --output artifacts/kinetic_typography/field.png
```

The reference's full dense grid is reproduced from its own glyph outlines. The early activation rule is inferred from the frames, while the first 16 frames preserve the original glyph shapes exactly. This recreates the visual result, not the original author's source algorithm.
