import os
from pathlib import Path
from PIL import Image

FRAME_DIR = Path('artifacts/punch_frames')
DEST_DIR = Path(r'C:/Users/jisub/.gemini/antigravity/brain/d65f9082-4c10-457c-a279-0f587421acb6')

frames = sorted(FRAME_DIR.glob('*.png'))
if not frames:
    print('No frames found in', FRAME_DIR)
    exit(1)

images = [Image.open(f).convert('RGBA') for f in frames]
images[0].save(
    DEST_DIR / 'punch_combo.gif',
    save_all=True,
    append_images=images[1:],
    duration=33,
    loop=0
)
print('Saved', DEST_DIR / 'punch_combo.gif')

# Impact peak composite:
# Left third from frame 3 (Jab peak)
# Mid third from frame 4 (Cross peak)
# Right third from frame 5 (Hook peak)
f3 = images[min(3, len(images)-1)]
f4 = images[min(4, len(images)-1)]
f5 = images[min(5, len(images)-1)]

w, h = f3.size
col1_w = int(w / 3.0)
col2_w = int(w * 2.0 / 3.0)

comp = Image.new('RGBA', (w, h))
comp.paste(f3.crop((0, 0, col1_w, h)), (0, 0))
comp.paste(f4.crop((col1_w, 0, col2_w, h)), (col1_w, 0))
comp.paste(f5.crop((col2_w, 0, w, h)), (col2_w, 0))

comp.save(DEST_DIR / 'punch_combo_comparison.png')
print('Saved', DEST_DIR / 'punch_combo_comparison.png')
