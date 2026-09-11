"""Package armed vs unarmed comparisons and animated GIFs."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
artifacts_dir = root / 'artifacts'
frames_dir = artifacts_dir / 'unarmed_frames'

captured_files = sorted(frames_dir.glob('*.png'))
print(f"Found {len(captured_files)} captured frames.")

# Each captured frame is 640x360:
# Armed actor is at x=200, Unarmed actor is at x=440. Ground is at y=240.
# Let's crop each pose:
cell_w = 140
cell_h = 160
armed_x = 200 - cell_w // 2
unarmed_x = 440 - cell_w // 2
crop_y = 240 - cell_h + 15

n_actions = len(captured_files)
sheet_w = cell_w * n_actions
sheet_h = cell_h * 2 + 70

sheet = Image.new('RGB', (sheet_w, sheet_h), '#080d14')
draw = ImageDraw.Draw(sheet)

draw.text((10, 8), "ARMED WITH SWORD (RAISED/BENT GUARD ARM)", fill="#f0a060")
draw.text((10, cell_h + 38), "UNARMED STATE (LOWERED HANGING & NATURAL SWINGING ARM)", fill="#60e0a0")

action_names = ["IDLE", "WALK 1", "WALK 2", "SPRINT 1", "SPRINT 2", "JUMP APEX", "FALL DIVE", "LAND"]

for i, f in enumerate(captured_files):
    img = Image.open(f)
    crop_armed = img.crop((armed_x, crop_y, armed_x + cell_w, crop_y + cell_h))
    crop_unarmed = img.crop((unarmed_x, crop_y, unarmed_x + cell_w, crop_y + cell_h))
    
    sheet.paste(crop_armed, (i * cell_w, 28))
    sheet.paste(crop_unarmed, (i * cell_w, cell_h + 58))
    
    # Label each column
    draw.text((i * cell_w + 10, sheet_h - 18), action_names[i], fill="#8899aa")
    draw.line([(i * cell_w, 0), (i * cell_w, sheet_h)], fill="#1a2536", width=1)

draw.line([(n_actions * cell_w - 1, 0), (n_actions * cell_w - 1, sheet_h)], fill="#1a2536", width=1)
draw.line([(0, cell_h + 32), (sheet_w, cell_h + 32)], fill="#243448", width=2)

comparison_path = artifacts_dir / 'unarmed_comparison.png'
sheet.save(comparison_path)
print("Saved comparison sheet to:", comparison_path)

# Copy to brain artifacts directory
brain_dir = Path(r'C:/Users/jisub/.gemini/antigravity/brain/d65f9082-4c10-457c-a279-0f587421acb6')
sheet.save(brain_dir / 'unarmed_comparison.png')
print("Copied unarmed comparison to brain artifact directory.")
