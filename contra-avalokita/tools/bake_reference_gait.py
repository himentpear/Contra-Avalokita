"""Bake editable Bone2D tracks for Walk and Run (both Armed and Unarmed); no runtime IK."""
from pathlib import Path
import math
import re

SCENE = Path(__file__).resolve().parents[1] / 'scenes/mud_character.tscn'

TRACK_PATHS = [
    "Visual/Skeleton2D/Pelvis:position",
    "Visual/Skeleton2D/Pelvis:rotation",
    "Visual/Skeleton2D/Pelvis/Torso:position",
    "Visual/Skeleton2D/Pelvis/Torso:rotation",
    "Visual/Skeleton2D/Pelvis/Torso/Head:position",
    "Visual/Skeleton2D/Pelvis/Torso/Head:rotation",
    "Visual/Skeleton2D/Pelvis/Torso/UpperArmFront:rotation",
    "Visual/Skeleton2D/Pelvis/Torso/UpperArmFront/ForearmFront:rotation",
    "Visual/Skeleton2D/Pelvis/Torso/UpperArmFront/ForearmFront/HandFront:rotation",
    "Visual/Skeleton2D/Pelvis/Torso/UpperArmBack:rotation",
    "Visual/Skeleton2D/Pelvis/Torso/UpperArmBack/ForearmBack:rotation",
    "Visual/Skeleton2D/Pelvis/Torso/UpperArmBack/ForearmBack/HandBack:rotation",
    "Visual/Skeleton2D/Pelvis/ThighFront:rotation",
    "Visual/Skeleton2D/Pelvis/ThighFront/ShinFront:rotation",
    "Visual/Skeleton2D/Pelvis/ThighFront/ShinFront/FootFront:rotation",
    "Visual/Skeleton2D/Pelvis/ThighBack:rotation",
    "Visual/Skeleton2D/Pelvis/ThighBack/ShinBack:rotation",
    "Visual/Skeleton2D/Pelvis/ThighBack/ShinBack/FootBack:rotation"
]

def curve(keys, phase):
    for (a, x), (b, y) in zip(keys, keys[1:]):
        if a <= phase <= b:
            return x + (y - x) * (phase - a) / (b - a)
    return keys[-1][1]

def pose(p, run, armed=True):
    half = (p * 2) % 1
    # Lower center of gravity for sprint: lowered by ~1.7 units (closer to ground)
    height = curve([(0,-31.6),(.20,-30.5),(.48,-31.4),(.70,-33.8),(1,-31.6)], half) if run else curve([(0,-33.4),(.22,-32.5),(.50,-34.9),(.78,-34.5),(1,-33.4)],half)
    pelvis = (0.20 if run else .055) + (0.022 if run else .018) * math.sin(p*math.tau)
    chest = (0.26 if run else .075) + (0.016 if run else .012)*math.sin((p-.035)*math.tau*2)
    values = [(0,height), pelvis, (1.8 if run else 0,-22), chest-pelvis, (0,-14), -chest*.75]
    
    # Arm kinematics
    for front in (True,False):
        phase = p + (0 if front else .5)
        if armed:
            # Sword arm stays bent; free arm supplies larger counter-swing.
            upper = (.22 if front else .38) + (.16 if front else (.62 if run else .40))*math.cos(phase*math.tau)
            elbow = ((-1.55 if run else -1.27) if front else (-1.35 if run else -.75)) + (.12 if front else .25 if run else .22)*math.cos((phase-.055)*math.tau)
            wrist_world = (-.38 if run else -.26) + .05*math.sin((phase-.08)*math.tau)
            values.extend([upper-chest, elbow, wrist_world-upper-elbow if front else .06*math.sin((phase-.08)*math.tau)])
        else:
            # Unarmed: both arms hang down naturally and swing symmetrically (opposite phases)
            if run:
                # Sprint: dynamic running arm pump, swinging naturally through hip-to-chest arc
                upper = 0.38 + 0.62 * math.cos(phase * math.tau)
                elbow = -1.00 + 0.25 * math.cos((phase - 0.055) * math.tau)
                wrist = 0.06 * math.sin((phase - 0.08) * math.tau)
                values.extend([upper - chest, elbow, wrist])
            else:
                # Walk: relaxed hanging arms, swinging naturally in opposition to legs
                upper = 0.35 + 0.40 * math.cos(phase * math.tau)
                elbow = -0.65 + 0.20 * math.cos((phase - 0.055) * math.tau)
                wrist = 0.06 * math.sin((phase - 0.08) * math.tau)
                values.extend([upper - chest, elbow, wrist])

    # Leg kinematics
    for front in (True,False):
        q=(p+(0 if front else .5))%1
        if run:
            # Low center of gravity sprint: strong rear push-off to -17.2, low recovery trajectory
            x=curve([(0,7.6),(.10,.8),(.25,-9.0),(.32,-15.5),(.40,-17.2),(.52,-14.8),(.64,-5.0),(.76,5.8),(.86,8.2),(.94,8.0),(1,7.6)],q)
            y=curve([(0,-3.25),(.10,-3.25),(.25,-4.0),(.32,-7.5),(.40,-9.2),(.52,-19.5),(.64,-15.5),(.76,-8.2),(.86,-5.8),(.94,-4.5),(1,-3.25)],q)
            roll=curve([(0,-.10),(.10,0),(.25,.20),(.32,.58),(.60,.78),(.84,-.22),(1,-.10)],q)
        else:
            x=curve([(0,9),(.12,4.68),(.25,0),(.40,-5.4),(.55,-10.8),(.65,-6),(.76,4),(.88,8),(1,9)],q)
            y=curve([(0,-3.6),(.12,-3.25),(.25,-3.25),(.40,-4.5),(.55,-6),(.65,-10),(.76,-11),(.88,-8),(1,-3.6)],q)
            roll=curve([(0,-.17),(.12,0),(.25,0),(.40,.25),(.55,.45),(.76,.22),(.88,-.1),(1,-.17)],q)
        # Local hip offsets remain authored in the scene. Each side shares one curve.
        hip_y=height+(2 if front else -2)*math.sin(pelvis)
        # Targets relative to each hip retain exact half-cycle timing.
        dx,dy=x,y-hip_y
        distance=min(math.hypot(dx,dy),31.95)
        bend=2*math.acos(distance/32)
        thigh=math.atan2(-dx,dy)-bend/2
        values.extend([thigh-pelvis,bend,roll-thigh-bend])
    return values

def pose_backstep(p, armed=True):
    half = (p * 2) % 1
    # Height: stable retreat stance
    height = curve([(0, -33.4), (.25, -32.8), (.50, -33.6), (.75, -33.0), (1, -33.4)], half)
    pelvis = 0.06 + 0.015 * math.sin(p * math.tau)
    chest = 0.08 + 0.012 * math.sin((p - .035) * math.tau * 2)
    values = [(0, height), pelvis, (0, -22), chest - pelvis, (0, -14), -chest * .75]
    
    # Arm kinematics
    for front in (True, False):
        phase = p + (0 if front else .5)
        if armed:
            upper = (.22 if front else .38) + (.16 if front else .40) * math.cos(phase * math.tau)
            elbow = (-1.27 if front else -.75) + (.12 if front else .22) * math.cos((phase - .055) * math.tau)
            wrist_world = -.26 + .05 * math.sin((phase - .08) * math.tau)
            values.extend([upper - chest, elbow, wrist_world - upper - elbow if front else .06 * math.sin((phase - .08) * math.tau)])
        else:
            upper = 0.35 + 0.30 * math.cos(phase * math.tau)
            elbow = -0.65 + 0.18 * math.cos((phase - 0.055) * math.tau)
            wrist = 0.06 * math.sin((phase - 0.08) * math.tau)
            values.extend([upper - chest, elbow, wrist])
            
    # Leg kinematics (reversed stride: stance moves back to front, swing lifts and steps backward)
    for front in (True, False):
        q = (p + (0 if front else .5)) % 1
        x = curve([(0, -7.5), (.12, -4.0), (.25, 0.0), (.40, 4.5), (.52, 7.5),
                   (.62, 5.0), (.72, -1.0), (.85, -6.5), (.94, -8.0), (1, -7.5)], q)
        y = curve([(0, -3.50), (.12, -3.50), (.25, -3.50), (.40, -3.50), (.52, -3.90),
                   (.62, -7.5), (.72, -10.5), (.85, -7.5), (.94, -4.8), (1, -3.50)], q)
        roll = curve([(0, 0.075), (.12, 0.0), (.25, 0.0), (.40, -0.05), (.52, -0.18),
                      (.62, -0.12), (.72, 0.08), (.85, 0.20), (.94, 0.22), (1, 0.075)], q)
        hip_y = height + (2 if front else -2) * math.sin(pelvis)
        dx, dy = x, y - hip_y
        distance = min(math.hypot(dx, dy), 31.95)
        bend = 2 * math.acos(distance / 32)
        thigh = math.atan2(-dx, dy) - bend / 2
        values.extend([thigh - pelvis, bend, roll - thigh - bend])
    return values

def fmt(v):
    return f'Vector2({v[0]:.6f}, {v[1]:.6f})' if isinstance(v,tuple) else f'{v:.6f}'

def bake_or_create(text, resource_id, anim_name, run=False, armed=True, is_backstep=False):
    duration = 0.70 if is_backstep else (.6 if run else .8)
    frames = [pose_backstep(i/32, armed) if is_backstep else pose(i/32, run, armed) for i in range(32)]
    frames.append(frames[0])
    times = ', '.join(f'{duration*i/32:.6f}' for i in range(33))
    
    # Check if resource already exists
    pattern = rf'\[sub_resource type="Animation" id="{resource_id}"\].*?(?=\n\[sub_resource|\n\[node)'
    existing = re.search(pattern, text, re.S)
    
    block = f'[sub_resource type="Animation" id="{resource_id}"]\nlength = {duration:.2f}\nloop_mode = 1\n'
    for track_idx, path in enumerate(TRACK_PATHS):
        block += f'tracks/{track_idx}/type = "value"\n'
        block += f'tracks/{track_idx}/imported = false\n'
        block += f'tracks/{track_idx}/enabled = true\n'
        block += f'tracks/{track_idx}/path = NodePath("{path}")\n'
        block += f'tracks/{track_idx}/interp = 1\n'
        block += f'tracks/{track_idx}/loop_wrap = true\n'
        block += f'tracks/{track_idx}/keys = {{\n'
        block += '"times": PackedFloat32Array(' + times + '),\n'
        block += '"transitions": PackedFloat32Array(' + ', '.join(['1']*33) + '),\n'
        block += '"update": 0,\n'
        block += '"values": [' + ', '.join(fmt(f[track_idx]) for f in frames) + ']\n'
        block += '}\n'
        
    if existing:
        text = text[:existing.start()] + block.rstrip() + text[existing.end():]
    else:
        # Insert before AnimationLibrary_pcne2
        lib_idx = text.index('[sub_resource type="AnimationLibrary" id="AnimationLibrary_pcne2"]')
        text = text[:lib_idx] + block + '\n' + text[lib_idx:]
        
    # Ensure animation name is in AnimationLibrary_pcne2
    entry = f'&"{anim_name}": SubResource("{resource_id}")'
    if f'&"{anim_name}"' not in text:
        text = re.sub(
            r'(\[sub_resource type="AnimationLibrary" id="AnimationLibrary_pcne2"\]\n_data = \{\n)',
            r'\1' + entry + ',\n',
            text
        )
    return text

if __name__ == '__main__':
    text = SCENE.read_text(encoding='utf-8')
    # 1. Armed Walk and Run (standard)
    text = bake_or_create(text, 'Animation_5jsxo', 'Walk', run=False, armed=True)
    text = bake_or_create(text, 'Animation_4t4rj', 'Run', run=True, armed=True)
    # 2. Unarmed Walk and Run (hanging & swinging naturally)
    text = bake_or_create(text, 'Animation_walk_unarmed', 'Walk_Unarmed', run=False, armed=False)
    text = bake_or_create(text, 'Animation_run_unarmed', 'Run_Unarmed', run=True, armed=False)
    # 3. Armed and Unarmed Backstep (tactical retreat step)
    text = bake_or_create(text, 'Animation_backstep', 'Backstep', armed=True, is_backstep=True)
    text = bake_or_create(text, 'Animation_backstep_unarmed', 'Backstep_Unarmed', armed=False, is_backstep=True)
    
    SCENE.write_text(text, encoding='utf-8', newline='\n')
    print('Successfully baked Armed and Unarmed Walk, Run, and Backstep animations into scenes/mud_character.tscn.')
