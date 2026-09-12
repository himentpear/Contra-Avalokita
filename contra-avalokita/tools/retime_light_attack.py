"""Make the light blade opener the fastest clip; preserve its authored poses."""
from pathlib import Path
import re
p=Path(__file__).resolve().parents[1]/'scenes/mud_character.tscn'
s=p.read_text(encoding='utf-8')
m=re.search(r'\[sub_resource type="Animation" id="BladeAttack1"\].*?(?=\n\[)',s,re.S)
b=m.group(0)
old=float(re.search(r'length = ([\d.]+)',b).group(1))
b=re.sub(r'length = [\d.]+','length = 0.4',b,count=1)
b=re.sub(r'"times": PackedFloat32Array\(([^)]*)\)',lambda x:'"times": PackedFloat32Array('+', '.join('%.6f'%(float(t)*.4/old) for t in x.group(1).split(','))+')',b)
p.write_text(s[:m.start()]+b+s[m.end():],encoding='utf-8',newline='\n')
