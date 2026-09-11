"""Adjust only Walk's pelvis height; preserve the user's current leg and arm keys."""
from pathlib import Path
import re,json
root=Path(__file__).resolve().parents[1]
path=root/'scenes/mud_character.tscn'
text=path.read_text(encoding='utf-8')
data=json.loads((root/'artifacts/grounded_walk_keys.json').read_text())
match=re.search(r'\[sub_resource type="Animation" id="Animation_5jsxo"\].*?(?=\n\[sub_resource)',text,re.S)
keys='"times": PackedFloat32Array('+', '.join('%.6f'%k[0] for k in data)+'),\n"transitions": PackedFloat32Array('+', '.join(['1']*len(data))+'),\n"update": 0,\n"values": ['+', '.join('Vector2(%.6f, %.6f)'%(k[1],k[2]) for k in data)+']\n}'
block=re.sub(r'(tracks/0/keys = \{\n).*?\n\}',lambda m:m.group(1)+keys,match.group(0),flags=re.S)
path.write_text(text[:match.start()]+block+text[match.end():],encoding='utf-8',newline='\n')
