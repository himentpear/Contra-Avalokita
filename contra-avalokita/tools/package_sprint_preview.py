"""Package captured Godot sprint frames and generate animated GIF and side-by-side comparison spritesheet."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
artifacts_dir = root / 'artifacts'
frames_dir = artifacts_dir / 'sprint_frames'

captured_files = sorted(frames_dir.glob('*.png'))
print(f"Found {len(captured_files)} captured frames.")

# Load original uploaded sprite sheet
user_img_path = Path(r'C:/Users/jisub/.gemini/antigravity/brain/d65f9082-4c10-457c-a279-0f587421acb6/.user_uploaded/media_1789134818942.png')
orig_sheet = Image.open(user_img_path)

cells = [
    (3, 124),
    (131, 252),
    (259, 380),
    (387, 508),
    (515, 636),
    (643, 764),
    (771, 892),
    (899, 1020)
]

cell_w = 140
cell_h = 160
crop_x = 320 - cell_w // 2
crop_y = 240 - cell_h + 15

godot_crops = []
for f in captured_files:
    img = Image.open(f)
    crop = img.crop((crop_x, crop_y, crop_x + cell_w, crop_y + cell_h))
    godot_crops.append(crop)

# 1. Create side-by-side comparison spritesheet
# Row 1: Original sprite sheet frames
# Row 2: Godot SDF rendered character frames
sheet_w = cell_w * 8
sheet_h = cell_h * 2 + 60
combined_sheet = Image.new('RGB', (sheet_w, sheet_h), '#080d14')
draw = ImageDraw.Draw(combined_sheet)

draw.text((10, 8), "ORIGINAL SPRINT SPRITE REFERENCE (8 POSES)", fill="#90b0e0")
draw.text((10, cell_h + 38), "GODOT REDESIGNED SPRINT ANIMATION (LOW COG & FORWARD LEAN)", fill="#70e090")

for i in range(8):
    x0, x1 = cells[i]
    orig_crop = orig_sheet.crop((x0, 0, x1 + 1, 112))
    # Resize to fit cell height proportionally
    orig_resized = orig_crop.resize((cell_w - 10, int(112 * (cell_w - 10) / 122)), Image.Resampling.NEAREST)
    
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

draw.line([(8 * cell_w - 1, 0), (8 * cell_w - 1, sheet_h)], fill="#1a2536", width=1)
draw.line([(0, cell_h + 30), (sheet_w, cell_h + 30)], fill="#243448", width=2)

comparison_path = artifacts_dir / 'sprint_comparison.png'
combined_sheet.save(comparison_path)
print("Saved comparison sheet to:", comparison_path)

# 2. Create animated GIF of the sprint sequence (0.6s / 8 frames = 75ms per frame)
gif_path = artifacts_dir / 'sprint_cycle.gif'
godot_crops[0].save(
    gif_path,
    save_all=True,
    append_images=godot_crops[1:],
    duration=75,
    loop=0
)
print("Saved animated sprint GIF to:", gif_path)

# Copy to brain artifacts directory
brain_dir = Path(r'C:/Users/jisub/.gemini/antigravity/brain/d65f9082-4c10-457c-a279-0f587421acb6')
combined_sheet.save(brain_dir / 'sprint_comparison.png')
godot_crops[0].save(brain_dir / 'sprint_cycle.gif', save_all=True, append_images=godot_crops[1:], duration=75, loop=0)
print("Copied preview images to artifact directory.")
