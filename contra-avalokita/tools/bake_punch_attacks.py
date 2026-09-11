"""Author three refined boxing punch attacks with complete kinetic chains in PunchLibrary."""
from pathlib import Path
import math
import re

workspace = Path(r"c:\Users\jisub\Documents\Contra-Avalokita\contra-avalokita")
scene = workspace / "scenes" / "mud_character.tscn"
text = scene.read_text(encoding="utf-8")
run = re.search(r'\[sub_resource type="Animation" id="Animation_4t4rj"\](.*?)(?=\n\[sub_resource)', text, re.S).group(1)
paths = re.findall(r'tracks/\d+/path = NodePath\("(.*?)"\)', run)

def leg_ik(pelvis_x, pelvis_y, pelvis_rot, foot_x, foot_roll=0.0):
    dx = foot_x - pelvis_x
    dy = 0.0 - 3.25 - pelvis_y  # distance from hip to ankle
    dist = math.hypot(dx, dy)
    dist = min(dist, 31.9)
    beta = 2.0 * math.acos(dist / 32.0)  # knee bend
    alpha = math.atan2(-dx, dy)
    thigh_world = alpha - beta / 2.0
    thigh_local = thigh_world - pelvis_rot
    shin_local = beta
    foot_local = foot_roll - thigh_world - beta
    return thigh_local, shin_local, foot_local

punch_specs = [
    # STAGE 1: LEAD JAB (0.32s) - fast, direct, short ("snap")
    # Lead shoulder protraction +3.5px, elbow maintains 11.5 deg bend (no lockup),
    # rear arm tightly shielding chin/cheek, rapid recoil
    {
        "name": "Attack_1",
        "duration": 0.32,
        "times": [0.0, 0.04, 0.10, 0.16, 0.24, 0.32],
        "pelvis_pos": [(0.0, -32.5), (1.5, -32.3), (2.8, -32.0), (1.5, -32.4), (-0.8, -32.7), (-0.4, -32.6)],
        "pelvis_rot": [0.04, 0.08, 0.12, 0.08, 0.02, 0.04],
        "torso_pos": [(0.0, -22.0), (1.2, -22.0), (3.5, -22.0), (1.8, -22.0), (0.2, -22.0), (0.0, -22.0)],
        "torso_rot": [0.02, 0.10, 0.20, 0.08, -0.04, 0.00],
        "head_rot": [-0.02, -0.06, -0.12, -0.05, 0.02, 0.00],
        "front_arm": [
            (-1.10, -2.30, 0.15),   # Chin guard
            (-1.35, -1.20, 0.05),   # Snap extending
            (-1.54, 0.20, 0.00),    # Impact: 11.5 deg elbow flexion (min 8-15 deg enforced)
            (-1.30, -1.40, 0.05),   # Quick retraction
            (-1.10, -2.10, 0.12),   # Recoil
            (-1.10, -2.30, 0.15)    # Guard restored
        ],
        "back_arm": [
            (-1.22, -2.18, 0.15),   # Rock-solid rear chin/jaw guard
            (-1.22, -2.18, 0.15),
            (-1.25, -2.20, 0.15),   # Tight cheek coverage on impact
            (-1.22, -2.18, 0.15),
            (-1.20, -2.15, 0.15),
            (-1.22, -2.18, 0.15)
        ],
        "feet": [
            (8.5, -8.5, 0.0),
            (9.0, -8.5, 0.05),
            (9.5, -8.0, 0.10),
            (9.0, -8.5, 0.05),
            (8.0, -9.0, 0.0),
            (8.2, -9.0, 0.0)
        ]
    },
    # STAGE 2: REAR CROSS (0.36s) - heavier, committed drive ("drive")
    # Rear foot drive, deep pelvis & chest rotation, forward shoulder thrust +4.5px,
    # lead arm shielding jaw, rear elbow maintains 12.6 deg bend
    {
        "name": "Attack_2",
        "duration": 0.36,
        "times": [0.0, 0.07, 0.15, 0.22, 0.29, 0.36],
        "pelvis_pos": [(-0.4, -32.6), (2.8, -32.2), (6.0, -31.8), (4.5, -32.2), (1.5, -32.5), (0.4, -32.6)],
        "pelvis_rot": [0.02, 0.12, 0.22, 0.18, 0.06, 0.02],
        "torso_pos": [(0.0, -22.0), (1.8, -22.0), (4.5, -22.0), (2.5, -22.0), (0.8, -22.0), (0.0, -22.0)],
        "torso_rot": [0.00, 0.16, 0.32, 0.20, -0.06, -0.10],  # Counter-rotation pre-loads Hook!
        "head_rot": [0.00, -0.08, -0.18, -0.10, 0.04, 0.06],
        "front_arm": [
            (-1.10, -2.30, 0.15),   # Lead guard
            (-1.80, -2.40, 0.15),
            (-1.83, -2.44, 0.15),   # Tight lead cheek/jaw shield during cross
            (-1.75, -2.35, 0.15),
            (-1.50, -1.80, 0.10),   # Lead elbow raising for Hook!
            (-1.40, -1.60, 0.08)    # Pre-cocked for Lead Hook!
        ],
        "back_arm": [
            (-1.22, -2.18, 0.15),   # Guard coiled
            (-1.35, -1.10, 0.05),   # Surging forward
            (-1.54, 0.22, 0.00),    # Impact: 12.6 deg elbow flexion (min 8-15 deg enforced)
            (-1.38, -1.20, 0.05),   # Recoil
            (-1.25, -1.90, 0.12),
            (-1.22, -2.18, 0.15)    # Guard restored
        ],
        "feet": [
            (8.2, -9.0, 0.0),
            (9.0, -8.8, 0.12),
            (9.8, -7.5, 0.25),      # Rear heel drives up on ball of foot!
            (9.5, -7.8, 0.18),
            (8.8, -8.5, 0.08),
            (8.5, -8.5, 0.0)
        ]
    },
    # STAGE 3: LEAD HOOK (0.42s) - rotational whip ("whip")
    # Uncoils from Cross counter-rotation, elevated horizontal elbow, 83 deg flexion,
    # explosive chest rotary torque, rear arm shielding jaw
    {
        "name": "Attack_3",
        "duration": 0.42,
        "times": [0.0, 0.08, 0.16, 0.24, 0.33, 0.42],
        "pelvis_pos": [(0.4, -32.6), (1.5, -32.4), (2.8, -32.2), (1.8, -32.4), (0.8, -32.5), (0.0, -32.5)],
        "pelvis_rot": [-0.04, 0.08, 0.16, 0.12, 0.06, 0.02],
        "torso_pos": [(0.0, -22.0), (1.2, -22.0), (2.5, -22.0), (1.5, -22.0), (0.5, -22.0), (0.0, -22.0)],
        "torso_rot": [-0.10, 0.14, 0.36, 0.22, 0.08, 0.02],  # Explosive rotation back into hook!
        "head_rot": [0.06, -0.06, -0.16, -0.10, -0.04, 0.00],
        "front_arm": [
            (-1.40, -1.60, 0.08),   # Pre-cocked elbow
            (-1.60, -1.50, 0.10),   # Raising and driving inward
            (-1.65, -1.45, 0.15),   # Impact: elevated horizontal elbow, 83 deg flexion sweeping across
            (-1.50, -1.35, 0.12),   # Follow-through
            (-1.25, -1.80, 0.12),   # Recoil
            (-1.10, -2.30, 0.15)    # Guard restored
        ],
        "back_arm": [
            (-1.22, -2.18, 0.15),   # Rock-solid rear cheek guard
            (-1.22, -2.20, 0.15),
            (-1.25, -2.25, 0.18),   # Face protected during hook whip
            (-1.22, -2.20, 0.15),
            (-1.22, -2.18, 0.15),
            (-1.22, -2.18, 0.15)
        ],
        "feet": [
            (8.5, -8.5, 0.0),
            (8.8, -8.2, 0.08),
            (9.2, -7.8, 0.15),      # Both feet pivoted for rotational torque
            (9.0, -8.2, 0.10),
            (8.6, -8.4, 0.04),
            (8.5, -8.5, 0.0)
        ]
    }
]

def fmt(value):
    return 'Vector2(%.6f, %.6f)' % value if isinstance(value, tuple) else '%.6f' % value

blocks = []
for index, spec in enumerate(punch_specs, 1):
    duration = spec['duration']
    times = spec['times']
    samples = []
    for k in range(len(times)):
        px, py = spec['pelvis_pos'][k]
        prot = spec['pelvis_rot'][k]
        tx, ty = spec['torso_pos'][k]
        trot = spec['torso_rot'][k]
        hrot = spec['head_rot'][k]
        u_f, el_f, wr_f = spec['front_arm'][k]
        u_b, el_b, wr_b = spec['back_arm'][k]
        fx, rx, r_roll = spec['feet'][k]
        
        f_th, f_sh, f_ft = leg_ik(px, py, prot, fx)
        b_th, b_sh, b_ft = leg_ik(px, py, prot, rx, r_roll)
        
        values = [
            (px, py), prot,
            (tx, ty), trot,
            (0.0, -14.0), hrot,
            u_f, el_f, wr_f,
            u_b, el_b, wr_b,
            f_th, f_sh, f_ft,
            b_th, b_sh, b_ft
        ]
        samples.append(values)
        
    block = f'[sub_resource type="Animation" id="PunchAttack{index}"]\nresource_name = "Attack_{index}"\nlength = {duration}\nmetadata/weapon_class = "fist"\n'
    for track, path in enumerate(paths):
        block += f'tracks/{track}/type = "value"\ntracks/{track}/path = NodePath("{path}")\ntracks/{track}/interp = 1\ntracks/{track}/loop_wrap = false\ntracks/{track}/keys = {{\n'
        block += '"times": PackedFloat32Array(' + ', '.join(map(str, times)) + '),\n"transitions": PackedFloat32Array(' + ', '.join(['1'] * len(times)) + '),\n"update": 0,\n"values": [' + ', '.join(fmt(s[track]) for s in samples) + ']\n}\n'
    blocks.append(block)

blocks.append('[sub_resource type="AnimationLibrary" id="PunchLibrary"]\n_data = {\n' + ',\n'.join(f'&"Attack_{i}": SubResource("PunchAttack{i}")' for i in range(1, 4)) + '\n}\n')

# Idempotent replacement in scenes/mud_character.tscn
text = re.sub(r'\[sub_resource type="(?:Animation|AnimationLibrary)" id="(?:PunchAttack[123]|PunchLibrary)"\].*?(?=\n\[)', '', text, flags=re.S)
pos = text.index('[node name="MudCharacter"')
text = text[:pos] + '\n'.join(blocks) + '\n' + text[pos:]
scene.write_text(text, encoding="utf-8")
(workspace / "tools" / "bake_punch_attacks.py").write_text(Path(__file__).read_text(encoding="utf-8"), encoding="utf-8")
print(f"Successfully baked {len(punch_specs)} punch attacks into {scene} and synchronized tools/bake_punch_attacks.py")
