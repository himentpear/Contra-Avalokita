# RotoBone v3 — Mud Character Workspace

RotoBone v3 is an editor workflow layered over the existing `res://scenes/mud_character.tscn`. It does not create a replacement `Skeleton2D`, copy the Bone2D hierarchy, or edit the source scene's rest pose.

## Open the workspace

1. Enable the RotoBone plugin (the project already enables it).
2. Open `res://tests/rotobone_mud_character_test.tscn`.
3. Use the narrow **RotoBone v3** dock on the right. It should report `Mud Character · template detected`.
4. Select Idle, Walk, Run, Jump, Fall, Land, Wall Slide, Attack / Slash, Thrust, Roll, Hurt, or Death.
5. Select and rotate existing Bone2D nodes under `MudCharacterInstance/Visual/PoseRoot/Skeleton2D` in the 2D editor.
6. Move `RotoBoneAnchor` to align the sprite reference. The overlay intentionally follows this Marker2D; editor-only canvas offsets are not used.
7. Click a marker button to add a Contact (`○`), Extreme (`△`), Breakdown (`□`), or Impact (`✕`) marker at the current time.
8. Click **Bake Pose** to write rotation keys into the wrapper scene's `AnimationPlayer`, under the `RotoBone` animation library.

## Data flow and safety contract

- `RotoBoneMudCharacterAdapter` loads or finds the PackedScene instance, then detects its `CharacterBody2D`, `Skeleton2D`, and source `AnimationPlayer` by type.
- `RotoBoneSemanticBoneMapper` derives the hierarchy and semantic roles without changing nodes. The checked-in result is `addons/rotobone/v3/core/mud_character_bone_map.json`; `write_mapping()` can regenerate it after an intentional source-rig update.
- `RotoBoneAnimationProfile` holds the canonical action name, source clip, duration, reference sprite, and markers.
- `RotoBonePoseBaker` targets only the wrapper `AnimationPlayer`. It emits Bone2D `rotation` value tracks and, only when explicitly requested by API, a root `position` track.
- `Bone2D.rest`, bone length, hierarchy, Bone2D position, and scale are read-only. Temporary IK may be used while posing, but the baker never serializes IK state or scale.
- The original `mud_character.tscn` remains the single skeleton template. Profiles for Roll, Hurt, and Death are available for authoring even though the source scene currently has no matching reusable clip.

The v3 catalog deliberately excludes shooting, ledge grab/climb, air spin, dash, slide, punch, and jab workflows.

## Validation

Run:

```powershell
godot --headless --path . --script res://tests/rotobone_v3_test.gd
```

The test verifies PackedScene instancing, automatic type detection, the 17-bone hierarchy, semantic mapping, the exact action allowlist, visible marker data, isolated pose baking, and the no-rest/no-scale contract. A separate Git hash comparison should remain clean for `scenes/mud_character.tscn`.
