"""Author Mud's editable, non-looping blade AnimationLibrary resource."""
from pathlib import Path
import math
import re

project = Path(__file__).resolve().parents[3]
scene = project / 'scenes/mud_character.tscn'
output = project / 'characters/mud/animation/blade_animation_library.tres'
text = scene.read_text(encoding='utf-8')
run = re.search(r'\[sub_resource type="Animation" id="Animation_4t4rj"\](.*?)(?=\n\[sub_resource)', text, re.S).group(1)
paths = re.findall(r'tracks/\d+/path = NodePath\("(.*?)"\)',run)

# Preparation, anticipation, strike, follow-through, recovery, guard.
# Blade angles are continuous so the authored swing never takes a shortcut.
specs = [
    (.62, [0,.12,.23,.32,.43,.62], [-.38,-2.5,-1.3,.65,1.0,-.38], [.15,.65,-1.7,-1.25,-.6,.15]),
    (.58, [0,.10,.20,.29,.40,.58], [-.38,1.1,.45,-1.25,-1.8,-.38], [.15,.5,-1.3,-1.75,-.8,.15]),
    (.76, [0,.18,.30,.41,.54,.76], [-.38,1.8,.8,-.8,-2.2,-.38], [.15,.75,-.75,-1.9,-1.1,.15]),
]

def fmt(value):
    return 'Vector2(%.6f, %.6f)' % value if isinstance(value,tuple) else '%.6f' % value

blocks=[]
for index,(duration,times,blade,upper) in enumerate(specs,1):
    samples=[]
    for k in range(6):
        shift=[0,-1,2,3,1,0][k] * (1.25 if index==3 else 1)
        height=[-33,-32,-32.5,-32,-32.8,-33][k]
        lean=[.06,-.08,.13,.20,.11,.06][k]
        elbow=[-1.25,-1.55,-.8,-.55,-1.0,-1.25][k]
        values=[(shift,height),lean,(0,-22),0,(0,-14),-lean*.8]
        values += [upper[k]-lean,elbow,blade[k]-upper[k]-elbow]
        values += [.25+lean,.0-.65-.25*k/5,.0]
        # Stable split stance: FK keys baked from two fixed planted ankles.
        for side in (1,-1):
            dx=side*9-shift-side*2*math.cos(lean)
            dy=-3.25-height-side*2*math.sin(lean)
            bend=2*math.acos(min(math.hypot(dx,dy),31.95)/32)
            thigh=math.atan2(-dx,dy)-bend/2
            values += [thigh-lean,bend,-thigh-bend]
        samples.append(values)
    block=f'[sub_resource type="Animation" id="BladeAttack{index}"]\nresource_name = "Attack_{index}"\nlength = {duration}\nmetadata/weapon_class = "blade"\n'
    for track,path in enumerate(paths):
        block += f'tracks/{track}/type = "value"\ntracks/{track}/path = NodePath("{path}")\ntracks/{track}/interp = 1\ntracks/{track}/loop_wrap = false\ntracks/{track}/keys = {{\n'
        block += '"times": PackedFloat32Array('+', '.join(map(str,times))+'),\n"transitions": PackedFloat32Array(1, 1, 1, 1, 1, 1),\n"update": 0,\n"values": ['+', '.join(fmt(s[track]) for s in samples)+']\n}\n'
    blocks.append(block)
library = '[resource]\n_data = {\n'+',\n'.join(f'&"Attack_{i}": SubResource("BladeAttack{i}")' for i in range(1,4))+'\n}\n'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text('[gd_resource type="AnimationLibrary" load_steps=4 format=3]\n\n'+'\n'.join(blocks)+'\n'+library,encoding='utf-8',newline='\n')
print(f'Authored {output}: Blade/Attack_1, Blade/Attack_2, Blade/Attack_3')
# Apply the dedicated horizontal second attack after the shared first/third authoring.
import runpy
runpy.run_path(str(Path(__file__).with_name('bake_horizontal_attack.py')))
