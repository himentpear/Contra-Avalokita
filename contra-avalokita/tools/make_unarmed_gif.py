"""Create animated side-by-side GIF comparing Armed vs Unarmed sprinting."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
frames_dir = root / 'artifacts/unarmed_run_frames'

images = []
for p in sorted(frames_dir.glob('*.png')):
    im = Image.open(p)
    # Crop around both actors: x in [80, 560], y in [70, 260]
    crop = im.crop((80, 75, 560, 255))
    
    # Add text banner
    draw = ImageDraw.Draw(crop)
    draw.text((10, 8), "ARMED (SWORD)", fill="#f0a060")
    draw.text((250, 8), "UNARMED (LOWERED SWINGING ARM)", fill="#60e0a0")
    images.append(crop)

gif_path = root / 'artifacts/unarmed_run_cycle.gif'
images[0].save(
    gif_path,
    save_all=True,
    append_images=images[1:],
    duration=int(600 / len(images)),
    loop=0
)
print("Saved animated comparison GIF to:", gif_path)

brain_dir = Path(r'C:/Users/jisub/.gemini/antigravity/brain/d65f9082-4c10-457c-a279-0f587421acb6')
images[0].save(
    brain_dir / 'unarmed_run_cycle.gif',
    save_all=True,
    append_images=images[1:],
    duration=int(600 / len(images)),
    loop=0
)
print("Copied GIF to brain artifact directory.")
