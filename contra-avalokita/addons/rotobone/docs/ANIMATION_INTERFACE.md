# RotoBone Animation Interface v0.1

This interface separates **reference motion** from **gameplay animation state**. RotoBone never assumes that a sprite frame is a bone pose; the sprite is evidence used to trace a pose.

## 1. Reference clip contract

Each reference clip is described by `RotoBoneClip`:

```gdscript
clip_id: StringName
texture: Texture2D
frame_size: Vector2i
frame_count: int
frame_durations_ms: PackedInt32Array
loop: bool
anchor_mode: "feet" | "hip" | "contact" | "center" | "custom"
anchor_px: Vector2
source_facing: "right" | "left" | "side" | "back" | "front" | "neutral"
tags: PackedStringArray
```

The important design choice is that timing is an **array**, not only FPS. The sample pack contains mostly uniform frame timings, but `Punch Jab` already uses mixed 40/50 ms frames.

## 2. Skeleton semantic interface

Recommended semantic joint names for later retargeting:

```text
root
pelvis
torso
head
arm_back_upper
arm_back_lower
hand_back
arm_front_upper
arm_front_lower
hand_front
leg_back_upper
leg_back_lower
foot_back
leg_front_upper
leg_front_lower
foot_front
weapon_socket
```

Do not hard-code NodePaths into reference data. A later retarget map should bind these semantic names to the project's actual `Bone2D` paths.

## 3. Gameplay animation IDs covered by the supplied sample pack

### Locomotion
`idle`, `walk`, `run`, `crouch_idle`, `crouch_walk`, `sword_idle`, `sword_run`, `katana_walk`, `katana_run`.

### Air / traversal
`jump`, `jump_new`, `land`, `roll`, `dash`, `slide`, `air_spin`, `wall_slide`, `wall_land`, `ledge_climb`, `climb_side`, `climb_back`.

### Combat
`punch`, `punch_jab`, `punch_cross`, `shoot_2h`, `shoot_run`, `aim_run`, `sword_attack`, `sword_stab`, `katana_attack_sheathe`, `katana_run_attack_upper`, `katana_air_attack`, `katana_continuous_attack`.

### Interaction / reaction
`push`, `pull`, `push_pull_idle`, `hurt`, `death`.

## 4. Current shown example: climb_back

The image shown in the conversation is byte-identical to:

`Climb (facing back of player)/player climb-back 48x48.png`

Metadata extracted from the accompanying Aseprite file:

```text
frame size      48 × 48
frame count     4
duration/frame  185 ms
cycle duration  740 ms
reference role  traversal / contact-anchored
```

For this action, do not use a feet anchor. The character is constrained by the climbing surface, so the reference should be aligned around a body/contact anchor and then fine-tuned with `Offset X/Y`.

## 5. V0.1 safety contract

RotoBone v0.1 is intentionally non-destructive:

- never writes `Bone2D.rest`;
- never changes bone length;
- never changes bone scale;
- never inserts animation keys;
- never edits scene transforms;
- only draws an editor viewport overlay.

This means the first version can be used while manually posing bones with Godot's normal Skeleton2D tools without risking rest-pose drift.

## 6. Planned interface extensions

The next safe additions are:

```text
PoseMarker[]        manual head/shoulder/elbow/wrist/hip/knee/ankle markers
BoneSemanticMap     semantic joint -> Bone2D NodePath
PoseKeyWriter       rotation-only key insertion through EditorUndoRedoManager
TwoBoneIKHint       limb target + bend direction / pole hint
ContactMarker[]     wall/ground/weapon contact constraints
```

The plugin should only gain transform-writing capabilities after those operations are Undo/Redo-safe and explicitly separated from rest-pose editing.
