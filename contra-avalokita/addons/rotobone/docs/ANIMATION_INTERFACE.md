# RotoBone Animation Interface v0.2

This interface separates **reference motion**, **reference registration**, and **gameplay animation state**. A sprite frame is evidence for a pose, not a bone pose by itself.

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

Timing remains an array rather than a single FPS because the supplied sample pack contains animations with non-uniform frame durations.

## 2. Two coordinate spaces

V0.2 deliberately separates two things that were mixed together in V0.1.

### Scene-space position

```text
RotoBoneAnchor : Marker2D
    position.x -> reference world X
    position.y -> reference world Y
```

The user moves this node with Godot's normal 2D transform gizmo. There is no second visible `Offset X/Y` control in the dock.

### Sprite-space pivot

```text
anchor_px / Pivot X/Y
```

This identifies the pixel *inside one sprite frame* that is placed exactly on `RotoBoneAnchor`.

Therefore:

```text
world placement               = RotoBoneAnchor.global_transform
sprite internal registration  = anchor_px
```

This split prevents selecting a different `Bone2D` from moving the reference image.

## 3. Skeleton semantic interface

Recommended semantic joint names:

```text
pelvis
torso
chest
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

Reference data should not hard-code project-specific NodePaths. A later retarget map should bind semantic names to the project's actual `Bone2D` paths.

## 4. Standard rig contract

The **+ Rig** action generates a compact side-view tracing scaffold sized for the supplied 48×48 template family.

```text
RotoBoneRig
├── Skeleton2D
│   └── pelvis
│       ├── torso
│       │   └── chest
│       │       ├── head
│       │       ├── arm_front_upper -> arm_front_lower -> hand_front
│       │       └── arm_back_upper  -> arm_back_lower  -> hand_back
│       ├── leg_front_upper -> leg_front_lower -> foot_front
│       └── leg_back_upper  -> leg_back_lower  -> foot_back
└── AnimationPlayer
```

Creation-time behavior:

- uses real `Bone2D` nodes so the user can manipulate them with Godot's native skeleton editor;
- gives every bone a fixed initial gizmo length and angle;
- captures each initial local transform into `Bone2D.rest` exactly once;
- attaches a `rotobone_semantic` metadata value to each bone;
- creates an empty `trace_pose` animation in `AnimationPlayer`.

The rig root is pelvis-centered. When inserted, RotoBone estimates the visual hip around 52% of frame height and places the pelvis under that point. This gives a useful first alignment for both feet-anchored locomotion and contact-anchored traversal without binding the rig to one specific animation.

## 5. Gameplay animation IDs covered by the supplied sample pack

### Locomotion
`idle`, `walk`, `run`, `crouch_idle`, `crouch_walk`, `sword_idle`, `sword_run`, `katana_walk`, `katana_run`.

### Air / traversal
`jump`, `jump_new`, `land`, `roll`, `dash`, `slide`, `air_spin`, `wall_slide`, `wall_land`, `ledge_climb`, `climb_side`, `climb_back`.

### Combat
`punch`, `punch_jab`, `punch_cross`, `shoot_2h`, `shoot_run`, `aim_run`, `sword_attack`, `sword_stab`, `katana_attack_sheathe`, `katana_run_attack_upper`, `katana_air_attack`, `katana_continuous_attack`.

### Interaction / reaction
`push`, `pull`, `push_pull_idle`, `hurt`, `death`.

## 6. Current shown example: climb_back

The shown reference corresponds to:

```text
Climb (facing back of player)/player climb-back 48x48.png
```

Its catalog metadata is:

```text
frame size      48 × 48
frame count     4
duration/frame  185 ms
cycle duration  740 ms
anchor mode     contact
anchor_px       (24.0, 26.88)
```

Because this is a contact/traversal animation, the reference pivot sits substantially above the feet. The standard rig therefore estimates a hip point separately instead of assuming the position marker always means "feet".

## 7. Safety contract

The tracing overlay does not automatically write:

- `Bone2D.rest` after sample-rig creation;
- bone scale;
- bone length after sample-rig creation;
- animation keys;
- CharacterBody2D/runtime movement.

The only intentional scene edits in V0.2 are explicit user actions:

```text
+ Pos -> create a Marker2D position anchor
+ Rig -> create a disposable sample Skeleton2D hierarchy
```

Both actions are routed through editor Undo/Redo.

## 8. Next safe extension

The next animation-writing layer should be:

```text
PoseMarker[]
    -> BoneSemanticMap
    -> rotation-only PoseKeyWriter
    -> EditorUndoRedoManager
```

Only after this is stable should the plugin add two-bone IK and contact constraints. This keeps pose editing separate from rest-pose editing and prevents the tracing tool from becoming another source of skeleton drift.
