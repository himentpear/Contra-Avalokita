# RotoBone v3 — Mud Character Workspace

RotoBone v3 is an editor workflow layered over the existing `res://scenes/mud_character.tscn`. It does not create a replacement `Skeleton2D`, copy the Bone2D hierarchy, or edit the source scene's rest pose.

## Open the workspace

1. Enable the RotoBone plugin (the project already enables it).
2. Open `res://tests/rotobone_mud_character_test.tscn`.
3. Use the narrow **RotoBone v3** dock on the right. It should report `Mud Character · template detected`.
4. Select Idle, Walk, Run, Jump, Fall, Land, Wall Slide, Attack / Slash, Thrust, Roll, Hurt, or Death.
5. Use **Asset action directory** to browse every action folder shipped under the pixel-art template. Selecting an entry switches the reference overlay and, when mapped, selects its canonical RotoBone profile.
6. Select and rotate existing Bone2D nodes under `MudCharacterInstance/Visual/PoseRoot/Skeleton2D` in the 2D editor.
7. Move `RotoBoneAnchor` to align the sprite reference. The overlay intentionally follows this Marker2D; editor-only canvas offsets are not used.
8. Click a marker button to add a Contact (`○`), Extreme (`△`), Breakdown (`□`), or Impact (`✕`) marker at the current time.
9. Click **Bake Pose** to write rotation keys into the wrapper scene's `AnimationPlayer`, under the `RotoBone` animation library.

The wrapper `AnimationPlayer` also exposes an editable `AssetActions` library. It contains one animation for each of the 36 asset folders. Placeholder lengths are initialized from the sprite-sheet frame count at 12 FPS, obvious cycles are configured to loop, and every sprite frame appears as an `F01…Fn` marker. All 17 existing Bone2D rotation tracks have a key at every marked frame. Mapped actions start from sampled source poses; actions without a source clip start from the neutral pose. Rotation tracks use cubic-angle interpolation for smooth, wrap-safe transitions. This external library belongs to the RotoBone workspace and never modifies the source character's animation libraries.

Regenerate the derived library after changing the asset catalog with:

```powershell
godot --headless --path . --script res://addons/rotobone/v3/tools/build_asset_action_placeholders.gd
```

## Data flow and safety contract

- `RotoBoneMudCharacterAdapter` loads or finds the PackedScene instance, then detects its `CharacterBody2D`, `Skeleton2D`, and source `AnimationPlayer` by type.
- `RotoBoneSemanticBoneMapper` derives the hierarchy and semantic roles without changing nodes. The checked-in result is `addons/rotobone/v3/core/mud_character_bone_map.json`; `write_mapping()` can regenerate it after an intentional source-rig update.
- `RotoBoneAnimationProfile` holds the canonical action name, source clip, duration, reference sprite, and markers.
- `asset_action_catalog.json` mirrors all 36 action folders in the source asset pack. Each row records its primary sprite sheet, cell dimensions, canonical action, source AnimationPlayer clip, and whether the mapping is direct, reference-only, or excluded.
- `RotoBonePoseBaker` targets only the wrapper `AnimationPlayer`. It emits Bone2D `rotation` value tracks and, only when explicitly requested by API, a root `position` track.
- `Bone2D.rest`, bone length, hierarchy, Bone2D position, and scale are read-only. Temporary IK may be used while posing, but the baker never serializes IK state or scale.
- `RotoBonePoseGuard` enforces rotation-only authoring inside the workspace. Moving, scaling, skewing, changing rest/length, or reparenting a bone is immediately restored while its rotation is preserved. Use the Rotate tool (`E`) instead of dragging with the Move tool.
- `Torso` is the animated semantic spine/chest. `SpineLower` and `SpineUpper` are renderer helper bones under Pelvis, not a second authored torso chain. The viewport draws an amber `SpineUpper → Torso` renderer bridge so this intentional non-parent connection remains visible without changing the source hierarchy or its animation paths.
- `AssetActions/Sword Attack` is authored from the six-frame `Sword Attack/player sword atk 64x64.png` reference. `sword_attack_pose.json` stores the per-frame hand targets and exact weapon-axis angles; the library builder solves the front arm with two-bone IK and derives the wrist rotation. `SwordPreview` follows HandFront in the editor so grip and blade direction remain visible while scrubbing.
- The original `mud_character.tscn` remains the single skeleton template. Profiles for Roll, Hurt, and Death are available for authoring even though the source scene currently has no matching reusable clip.

The v3 catalog deliberately excludes shooting, ledge grab/climb, air spin, dash, slide, punch, and jab workflows.

## Validation

Run:

```powershell
godot --headless --path . --script res://tests/rotobone_v3_test.gd
```

The test verifies PackedScene instancing, automatic type detection, the 17-bone hierarchy, semantic mapping, the exact action allowlist, visible marker data, isolated pose baking, and the no-rest/no-scale contract. A separate Git hash comparison should remain clean for `scenes/mud_character.tscn`.
