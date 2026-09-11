"""Editable compact jump poses, independent of the action overlay."""
from pathlib import Path
import math,re
p=Path(__file__).resolve().parents[1]/'scenes/mud_character.tscn'
s=p.read_text(encoding='utf-8')
b=re.search(r'id="BladeAttack1"\](.*?)(?=\n\[)',s,re.S).group(1)
paths=re.findall(r'tracks/\d+/path = NodePath\("(.*?)"\)',b)[:18]
# pelvis height, chest length, front thigh/knee, rear thigh/knee (degrees).
guard=(-34.8,22,-10,20, -10,20)
squat=(-31.5,21,-20,40,-20,40)
extend=(-35,23,5,12,12,18)
rise=(-34,23,-25,58,12,72)
apex=(-33,22,-42,82,-12,72)
fall=(-34,22,-8,24,7,30)
soft=(-32,21,-20,40,-20,40)
hard=(-29.7,20,-28,56,-28,56)
specs={'JumpSquat':(.075,[guard,squat],True),'Takeoff':(.075,[squat,extend,rise],False),'Rise':(.25,[rise,apex],False),'Apex':(.12,[apex,apex],False),'Fall':(.35,[apex,fall,extend],False),'SoftLand':(.18,[fall,soft,guard],True),'HardLand':(.27,[fall,hard,soft,guard],True)}
blocks=[]
for name,(duration,poses,ground) in specs.items():
    rows=[]
    for h,chest,tf,kf,tb,kb in poses:
        v=[(0,h),0,(0,-chest),.07,(0,-14),-.07,.15,-1.35,-.07,.35,-.85,0]
        for side,(thigh,knee) in zip((1,-1),((tf,kf),(tb,kb))):
            if ground:
                dx=side*2; dy=-3.25-h
                knee=2*math.acos(min(math.hypot(dx,dy),31.95)/32)
                thigh=math.atan2(-dx,dy)-knee/2
            else: thigh,knee=map(math.radians,(thigh,knee))
            v += [thigh,knee,-thigh-knee]
        rows.append(v)
    block=f'[sub_resource type="Animation" id="Air{name}"]\nresource_name = "{name}"\nlength = {duration}\n'
    for i,path in enumerate(paths):
        block+=f'tracks/{i}/type = "value"\ntracks/{i}/path = NodePath("{path}")\ntracks/{i}/interp = 1\ntracks/{i}/keys = {{\n"times": PackedFloat32Array('+', '.join(str(duration*k/(len(rows)-1)) for k in range(len(rows)))+'),\n"transitions": PackedFloat32Array('+', '.join(['1']*len(rows))+'),\n"update": 0,\n"values": ['+', '.join('Vector2(%.6f, %.6f)'%r[i] if isinstance(r[i],tuple) else '%.6f'%r[i] for r in rows)+']\n}\n'
    blocks.append(block)
blocks.append('[sub_resource type="AnimationLibrary" id="AirLibrary"]\n_data = {\n'+',\n'.join(f'&"{name}": SubResource("Air{name}")' for name in specs)+'\n}\n')
s=re.sub(r'\[sub_resource type="(?:Animation|AnimationLibrary)" id="Air(?:JumpSquat|Takeoff|Rise|Apex|Fall|SoftLand|HardLand|Library)"\].*?(?=\n\[)', '',s,flags=re.S)
pos=s.index('[node name="MudCharacter"')
s=s[:pos]+'\n'.join(blocks)+'\n'+s[pos:]
s=re.sub(r'\nlibraries/Air = SubResource\("AirLibrary"\)', '',s)
s=re.sub(r'(\[node name="AnimationPlayer"[^\n]*\]\n)',r'\1libraries/Air = SubResource("AirLibrary")\n',s)
p.write_text(s,encoding='utf-8',newline='\n')
