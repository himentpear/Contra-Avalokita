"""Package captured Godot frames for animation review (Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / 'artifacts'
frames = [Image.open(p).convert('RGB') for p in sorted((root/'reference_frames').glob('*.png'))]
frames[0].save(root/'reference_walk_run.gif', save_all=True, append_images=frames[1:], duration=[30,30,40]*24, loop=0)
sheet = Image.new('RGB',(1280,480),'#0a1117')
for row, period in enumerate((24,18)):
    for column in range(8):
        frame = frames[round(column*period/8)]
        x = 0 if row == 0 else 320
        crop=frame.crop((x+40,75,x+255,295)).resize((156,160),Image.Resampling.NEAREST)
        sheet.paste(crop,(column*160,row*230+45))
ImageDraw.Draw(sheet).text((10,10),'WALK / 8 cycle poses',fill='white')
ImageDraw.Draw(sheet).text((10,240),'RUN / 8 cycle poses',fill='white')
sheet.save(root/'reference_walk_run_poses.png')
