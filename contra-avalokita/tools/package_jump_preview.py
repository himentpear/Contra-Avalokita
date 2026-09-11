"""Package captured Godot jump frames and generate animated GIF and side-by-side comparison spritesheet."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
artifacts_dir = root / 'artifacts'
frames_dir = artifacts_dir / 'jump_frames'

captured_files = sorted(frames_dir.glob('*.png'))
print(f"Found {len(captured_files)} captured frames.")

# Load original uploaded sprite sheet
user_img_path = Path(r'C:/Users/jisub/.gemini/antigravity/brain/d65f9082-4c10-457c-a279-0f587421acb6/.user_uploaded/media_1789132990132.png')
orig_sheet = Image.open(user_img_path)

cells = [
    (2, 91),
    (95, 184),
    (188, 277),
    (281, 370),
    (374, 463),
    (467, 556),
    (560, 649),
    (653, 742),
    (746, 835),
    (840, 928),
    (933, 1021)
]

# Crop character from each captured 640x360 frame:
# Actor is at Vector2(320, 240) scaled 2.5x.
# Character bounding box is roughly x in [220, 420], y in [50, 260].
cell_w = 120
cell_h = 160
crop_x = 320 - cell_w // 2
crop_y = 240 - cell_h + 15

godot_crops = []
for f in captured_files:
    img = Image.open(f)
    crop = img.crop((crop_x, crop_y, crop_x + cell_w, crop_y + cell_h))
    godot_crops.append(crop)

# 1. Create side-by-side comparison spritesheet
# Row 1: Original sprite sheet frames (scaled up)
# Row 2: Godot SDF rendered character frames
sheet_w = cell_w * 11
sheet_h = cell_h * 2 + 60
combined_sheet = Image.new('RGB', (sheet_w, sheet_h), '#080d14')
draw = ImageDraw.Draw(combined_sheet)

draw.text((10, 8), "ORIGINAL SPRITE REFERENCE (11 FRAMES)", fill="#90b0e0")
draw.text((10, cell_h + 38), "GODOT REDESIGNED JUMP ANIMATION (SDF SKELETON RENDERED)", fill="#70e090")

for i in range(11):
    x0, x1 = cells[i]
    orig_crop = orig_sheet.crop((x0, 0, x1 + 1, 81))
    # Resize to fit cell height proportionally
    orig_resized = orig_crop.resize((cell_w - 10, int(81 * (cell_w - 10) / 90)), Image.Resampling.NEAREST)
    
    # Paste original
    py = 28 + (cell_h - orig_resized.size[1]) // 2
    px = i * cell_w + 5
    combined_sheet.paste(orig_resized, (px, py))
    
    # Paste Godot crop
    gy = cell_h + 58
    gx = i * cell_w
    combined_sheet.paste(godot_crops[i], (gx, gy))
    
    # Grid lines
    draw.line([(i * cell_w, 0), (i * cell_w, sheet_h)], fill="#1a2536", width=1)

draw.line([(11 * cell_w - 1, 0), (11 * cell_w - 1, sheet_h)], fill="#1a2536", width=1)
draw.line([(0, cell_h + 30), (sheet_w, cell_h + 30)], fill="#243448", width=2)

comparison_path = artifacts_dir / 'jump_comparison.png'
combined_sheet.save(comparison_path)
print("Saved comparison sheet to:", comparison_path)

# 2. Also create an animated GIF of the jump sequence!
# Durations for each frame to match physical jump timing:
# F0: 0.10s (ready)
# F1: 0.10s (takeoff)
# F2: 0.12s (ascending stretch)
# F3: 0.12s (ascending tuck)
# F4: 0.15s (apex float)
# F5: 0.12s (post-apex dive)
# F6: 0.12s (falling dive)
# F7: 0.10s (pre-landing reach)
# F8: 0.08s (landing impact squash)
# F9: 0.08s (landing recovery rise)
# F10: 0.15s (settle stand)
durations = [100, 100, 120, 120, 150, 120, 120, 100, 80, 80, 150]
gif_path = artifacts_dir / 'jump_cycle.gif'
godot_crops[0].save(
    gif_path,
    save_all=True,
    append_images=godot_crops[1:],
    duration=durations,
    loop=0
)
print("Saved animated jump GIF to:", gif_path)

# Copy comparison image and gif to brain artifacts directory for embedding
brain_dir = Path(r'C:/Users/jisub/.gemini/antigravity/brain/d65f9082-4c10-457c-a279-0f587421acb6')
combined_sheet.save(brain_dir / 'jump_comparison.png')
godot_crops[0].save(brain_dir / 'jump_cycle.gif', save_all=True, append_images=godot_crops[1:], duration=durations, loop=0)
print("Copied preview images to artifact directory.")
