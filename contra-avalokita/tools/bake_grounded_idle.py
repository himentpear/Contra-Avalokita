"""Keep Idle feet on the same y=0 sole plane as Walk, including breathing."""
from pathlib import Path
import math, re
path=Path(__file__).resolve().parents[1]/'scenes/mud_character.tscn'
text=path.read_text(encoding='utf-8')
pattern=r'\[sub_resource type="Animation" id="Animation_o2g5h"\].*?(?=\n\[sub_resource)'
match=re.search(pattern,text,re.S)
block=match.group(0)
times=[i*.05 for i in range(25)]
heights=[-34.8+.5*(1-math.cos(t/1.2*math.tau))*.5 for t in times]
tracks={0:['Vector2(0, %.6f)'%h for h in heights]}
for start in (12,15):
    bends=[2*math.acos((-3.25-h)/32) for h in heights]
    tracks[start]=['%.6f'%(-b/2) for b in bends]
    tracks[start+1]=['%.6f'%b for b in bends]
    tracks[start+2]=['%.6f'%(-b/2) for b in bends]
for track,values in tracks.items():
    keys='"times": PackedFloat32Array('+', '.join('%.3f'%t for t in times)+'),\n"transitions": PackedFloat32Array('+', '.join(['1']*25)+'),\n"update": 0,\n"values": ['+', '.join(values)+']\n}'
    block=re.sub(rf'(tracks/{track}/keys = \{{\n).*?\n\}}',lambda m:m.group(1)+keys,block,flags=re.S)
text=text[:match.start()]+block+text[match.end():]
path.write_text(text,encoding='utf-8',newline='\n')
