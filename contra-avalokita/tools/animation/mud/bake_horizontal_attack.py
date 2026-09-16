"""Replace Mud Blade/Attack_2 with a side-view horizontal cut."""
from pathlib import Path
import math, re
path=Path(__file__).resolve().parents[3]/'characters/mud/animation/blade_animation_library.tres'
text=path.read_text(encoding='utf-8')
base=re.search(r'\[sub_resource type="Animation" id="BladeAttack1"\](.*?)(?=\n\[)',text,re.S).group(1)
paths=re.findall(r'tracks/\d+/path = NodePath\("(.*?)"\)',base)
paths += ['Visual/WeaponSlots:blade_projection','Visual/WeaponSlots:blade_depth']
def curve(keys,t):
    for (a,x),(b,y) in zip(keys,keys[1:]):
        if a<=t<=b:
            s=(t-a)/(b-a); s=s*s*(3-2*s)
            return x+(y-x)*s
    return keys[-1][1]
samples=[]
for n in range(45):
    t=n/100
    shift=curve([(0,0),(.09,-1.6),(.16,.5),(.24,2),(.30,1.6),(.38,0),(.44,0)],t)
    height=curve([(0,-33),(.09,-32),(.18,-33),(.27,-32.8),(.44,-33)],t)
    pelvis=curve([(0,.06),(.07,-.11),(.18,.12),(.30,.14),(.38,.06),(.44,.06)],t)
    chest=curve([(0,.06),(.095,-.24),(.205,.26),(.29,.32),(.40,.06),(.44,.06)],t)
    sx=shift+22*math.sin(pelvis)+4*math.cos(chest)
    sy=height-22*math.cos(pelvis)+4*math.sin(chest)
    hx=curve([(0,14),(.115,-2),(.16,2),(.245,23),(.30,21),(.40,15),(.44,14)],t)
    hy=curve([(0,-36),(.115,-41),(.16,-42),(.25,-42),(.31,-40),(.44,-36)],t)
    dx,dy=hx-sx,hy-sy
    elbow=-2*math.acos(min(math.hypot(dx,dy),23.7)/24)
    upper=math.atan2(-dx,dy)-elbow/2
    blade=curve([(0,-.38),(.13,.13),(.17,.05),(.25,-.03),(.33,-.20),(.44,-.38)],t)
    vals=[(shift,height),pelvis,(0,-22),chest-pelvis,(0,-14),-chest*.85,upper-chest,elbow,blade-upper-elbow]
    vals += [curve([(0,.2),(.11,-.2),(.24,.85),(.33,.6),(.44,.2)],t)-chest,-.85,.05]
    for side in (1,-1):
        dx=side*9-shift-side*2*math.cos(pelvis)
        dy=-3.25-height-side*2*math.sin(pelvis)
        bend=2*math.acos(min(math.hypot(dx,dy),31.95)/32)
        thigh=math.atan2(-dx,dy)-bend/2
        vals += [thigh-pelvis,bend,-thigh-bend]
    # Project blade yaw onto the horizontal screen axis; no clock-hand circle.
    vals += [curve([(0,1),(.12,-.92),(.16,-.85),(.25,1.05),(.33,1),(.44,1)],t), -1 if t<.16 else (0 if t<.18 or t>.33 else 1)]
    samples.append(vals)
block='[sub_resource type="Animation" id="BladeAttack2"]\nresource_name = "Attack_2_Horizontal"\nlength = 0.44\nmetadata/weapon_class = "blade"\n'
for i,p in enumerate(paths):
    values=[('Vector2(%.6f, %.6f)'%v if isinstance(v,tuple) else '%.6f'%v) for v in [s[i] for s in samples]]
    block+=f'tracks/{i}/type = "value"\ntracks/{i}/path = NodePath("{p}")\ntracks/{i}/interp = 1\ntracks/{i}/loop_wrap = false\ntracks/{i}/keys = {{\n"times": PackedFloat32Array('+', '.join(str(n/100) for n in range(45))+'),\n"transitions": PackedFloat32Array('+', '.join(['1']*45)+'),\n"update": 0,\n"values": ['+', '.join(values)+']\n}\n'
text=re.sub(r'\[sub_resource type="Animation" id="BladeAttack2"\].*?(?=\n\[)',lambda _:block,text,flags=re.S)
path.write_text(text,encoding='utf-8',newline='\n')
