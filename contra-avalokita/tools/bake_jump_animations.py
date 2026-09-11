"""Bake redesigned Jump, Fall, and Land animations (both Armed and Unarmed)
into scenes/mud_character.tscn based on the jump sprite sheet.
"""
from pathlib import Path
import re

SCENE = Path(__file__).resolve().parents[1] / 'scenes/mud_character.tscn'

# 18 standard Skeleton2D track paths
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

def fmt(v):
    if isinstance(v, tuple):
        return f"Vector2({v[0]:.6f}, {v[1]:.6f})"
    return f"{v:.6f}"

# ARMED POSES
# Frame 0: Stand / Idle
F0 = [
    (0.0, -34.8), 0.0, (0.0, -22.0), 0.0, (0.0, -14.0), 0.0,
    0.05, -0.20, 0.0, -0.05, -0.15, 0.0,
    -0.17, 0.34, -0.17, -0.17, 0.34, -0.17
]
# Frame 1: Takeoff Launch
F1 = [
    (0.0, -35.8), 0.08, (0.0, -22.0), 0.18, (0.0, -14.0), -0.14,
    -0.65, -0.85, -0.18, 0.55, 0.35, 0.0,
    0.20, 0.35, -0.55, 0.45, 0.40, -0.85
]
# Frame 2: Ascending Stretch
F2 = [
    (0.0, -37.2), 0.05, (0.0, -22.0), 0.22, (0.0, -14.0), -0.16,
    -0.90, -1.10, -0.14, 0.65, 0.45, 0.0,
    0.10, 0.85, -0.95, 0.35, 0.95, -1.30
]
# Frame 3: Ascending Tuck
F3 = [
    (0.0, -36.0), 0.08, (0.0, -22.0), 0.16, (0.0, -14.0), -0.10,
    -0.55, -1.40, -0.10, 0.30, 0.85, 0.0,
    -0.85, 1.55, -0.70, -0.55, 1.45, -0.90
]
# Frame 4: Apex Float
F4 = [
    (0.0, -35.0), 0.06, (0.0, -22.0), 0.12, (0.0, -14.0), -0.08,
    -0.45, -1.50, -0.15, 0.25, 1.05, 0.0,
    -1.05, 1.85, -0.80, -0.75, 1.75, -1.00
]
# Frame 5: Post-Apex Descent
F5 = [
    (0.0, -35.5), 0.10, (0.0, -22.0), 0.18, (0.0, -14.0), -0.12,
    -0.30, -1.20, -0.10, 0.35, 0.70, 0.0,
    -0.60, 1.25, -0.65, -0.25, 1.20, -0.95
]
# Frame 6: Falling Dive
F6 = [
    (0.0, -36.5), 0.12, (0.0, -22.0), 0.20, (0.0, -14.0), -0.15,
    -0.15, -0.85, -0.05, 0.45, 0.55, 0.0,
    -0.30, 0.75, -0.45, 0.05, 0.80, -0.85
]
# Frame 7: Pre-Landing Reach
F7 = [
    (0.0, -36.0), 0.04, (0.0, -22.0), 0.10, (0.0, -14.0), -0.06,
    -0.35, -0.55, -0.05, 0.30, 0.40, 0.0,
    -0.15, 0.45, -0.30, 0.05, 0.50, -0.55
]
# Frame 8: Landing Impact & Squash
F8 = [
    (0.0, -28.8), 0.05, (0.0, -22.0), 0.22, (0.0, -14.0), -0.15,
    -0.10, -0.75, -0.10, 0.20, 0.50, 0.0,
    -0.70, 1.40, -0.70, -0.65, 1.30, -0.65
]
# Frame 9: Landing Recovery
F9 = [
    (0.0, -32.8), 0.02, (0.0, -22.0), 0.08, (0.0, -14.0), -0.05,
    0.00, -0.40, 0.0, 0.05, 0.20, 0.0,
    -0.35, 0.70, -0.35, -0.35, 0.70, -0.35
]
F10 = F0

# UNARMED POSES: front arm hangs naturally / lowered instead of raised guard
def make_unarmed(pose_armed, uaf, faf, hf=0.0):
    p = list(pose_armed)
    p[6] = uaf
    p[7] = faf
    p[8] = hf
    return p

F0_U = make_unarmed(F0, 0.05, 0.05, 0.0)
F1_U = make_unarmed(F1, 0.45, -0.40, 0.0)
F2_U = make_unarmed(F2, -0.75, -0.60, 0.0)
F3_U = make_unarmed(F3, -0.35, -0.70, 0.0)
F4_U = make_unarmed(F4, -0.20, -0.65, 0.0)
F5_U = make_unarmed(F5, 0.15, -0.55, 0.0)
F6_U = make_unarmed(F6, 0.25, -0.45, 0.0)
F7_U = make_unarmed(F7, -0.15, -0.35, 0.0)
F8_U = make_unarmed(F8, 0.05, -0.30, 0.0)
F9_U = make_unarmed(F9, 0.05, -0.15, 0.0)
F10_U = F0_U

ANIMATIONS = {
    # Armed
    "Animation_x6uq2": {
        "name": "Jump", "length": 0.38, "times": [0.0, 0.10, 0.22, 0.38], "poses": [F1, F2, F3, F4]
    },
    "Animation_bwoe3": {
        "name": "Fall", "length": 0.38, "times": [0.0, 0.16, 0.35], "poses": [F5, F6, F7]
    },
    "Animation_land0": {
        "name": "Land", "length": 0.16, "times": [0.0, 0.08, 0.16], "poses": [F8, F9, F10]
    },
    # Unarmed
    "Animation_jump_unarmed": {
        "name": "Jump_Unarmed", "length": 0.38, "times": [0.0, 0.10, 0.22, 0.38], "poses": [F1_U, F2_U, F3_U, F4_U]
    },
    "Animation_fall_unarmed": {
        "name": "Fall_Unarmed", "length": 0.38, "times": [0.0, 0.16, 0.35], "poses": [F5_U, F6_U, F7_U]
    },
    "Animation_land_unarmed": {
        "name": "Land_Unarmed", "length": 0.16, "times": [0.0, 0.08, 0.16], "poses": [F8_U, F9_U, F10_U]
    },
    "Animation_idle_unarmed": {
        "name": "Idle_Unarmed", "length": 1.20, "times": [0.0, 0.60, 1.20], "poses": [F0_U, make_unarmed([(0.0, -34.3), 0.0, (0.0, -22.0), 0.0, (0.0, -14.0), 0.0, 0.05, 0.05, 0.0, -0.05, 0.05, 0.0, -0.17, 0.34, -0.17, -0.17, 0.34, -0.17], 0.05, 0.05, 0.0), F0_U]
    }
}

def build_animation_block(anim_id: str, data: dict) -> str:
    length = data["length"]
    times = data["times"]
    poses = data["poses"]
    n_keys = len(times)
    loop = "loop_mode = 1\n" if "Idle" in data["name"] else ""
    
    block = f'[sub_resource type="Animation" id="{anim_id}"]\nlength = {length}\n{loop}'
    for track_idx, path in enumerate(TRACK_PATHS):
        block += f'tracks/{track_idx}/type = "value"\n'
        block += f'tracks/{track_idx}/imported = false\n'
        block += f'tracks/{track_idx}/enabled = true\n'
        block += f'tracks/{track_idx}/path = NodePath("{path}")\n'
        block += f'tracks/{track_idx}/interp = 1\n'
        block += f'tracks/{track_idx}/loop_wrap = false\n'
        block += f'tracks/{track_idx}/keys = {{\n'
        block += '"times": PackedFloat32Array(' + ', '.join(f'{t:.4f}' for t in times) + '),\n'
        block += '"transitions": PackedFloat32Array(' + ', '.join(['1'] * n_keys) + '),\n'
        block += '"update": 0,\n'
        values_str = ', '.join(fmt(poses[k][track_idx]) for k in range(n_keys))
        block += f'"values": [{values_str}]\n'
        block += '}\n'
    return block

def apply_to_scene():
    text = SCENE.read_text(encoding='utf-8')
    
    for anim_id, data in ANIMATIONS.items():
        anim_name = data["name"]
        anim_block = build_animation_block(anim_id, data)
        pattern = rf'\[sub_resource type="Animation" id="{anim_id}"\].*?(?=\n\[sub_resource|\n\[node)'
        if re.search(pattern, text, re.S):
            text = re.sub(pattern, anim_block.rstrip(), text, flags=re.S)
        else:
            lib_idx = text.index('[sub_resource type="AnimationLibrary" id="AnimationLibrary_pcne2"]')
            text = text[:lib_idx] + anim_block + '\n' + text[lib_idx:]
            
        entry = f'&"{anim_name}": SubResource("{anim_id}")'
        if f'&"{anim_name}"' not in text:
            text = re.sub(
                r'(\[sub_resource type="AnimationLibrary" id="AnimationLibrary_pcne2"\]\n_data = \{\n)',
                r'\1' + entry + ',\n',
                text
            )
            
    SCENE.write_text(text, encoding='utf-8', newline='\n')
    print("Successfully baked Jump, Fall, Land (Armed & Unarmed) into scenes/mud_character.tscn.")

if __name__ == '__main__':
    apply_to_scene()
