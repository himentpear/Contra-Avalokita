import os
from pathlib import Path
from PIL import Image

FRAME_DIR = Path('artifacts/backstep_frames')
DEST_DIR = Path(r'C:/Users/jisub/.gemini/antigravity/brain/d65f9082-4c10-457c-a279-0f587421acb6')

frames = sorted(FRAME_DIR.glob('*.png'))
if not frames:
    print('No frames found in', FRAME_DIR)
    exit(1)

images = [Image.open(f).convert('RGBA') for f in frames]
images[0].save(
    DEST_DIR / 'backstep_attack.gif',
    save_all=True,
    append_images=images[1:],
    duration=33,
    loop=0
)
print('Saved', DEST_DIR / 'backstep_attack.gif')

# Keyframe strip: pick 6 frames
key_indices = [0, 8, 16, 24, 32, 40]
key_images = [images[min(i, len(images)-1)] for i in key_indices]

w, h = key_images[0].size
# 2 rows x 3 columns
strip = Image.new('RGBA', (w * 3, h * 2), (24, 28, 38, 255))
for idx, img in enumerate(key_images):
    r = idx // 3
    c = idx % 3
    strip.paste(img, (c * w, r * h))

strip.save(DEST_DIR / 'backstep_attack_comparison.png')
print('Saved', DEST_DIR / 'backstep_attack_comparison.png')
