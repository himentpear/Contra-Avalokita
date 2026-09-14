# RotoBone v4

RotoBone v4 is a pose-annotation system. Editors manipulate semantic targets and pose markers; `Bone2D` is only the runtime execution layer.

## Data flow

`Reference Animation -> RotoPoseGraph -> RotoPoseSolver -> Skeleton2D -> SDF renderer`

`AnimationPlayer` is a playback container. A generated animation has one discrete value track targeting `RotoPoseController.current_pose`; it does not contain bone position, rotation, or scale tracks.

## Mud Character workflow

1. Open `res://tests/rotopose_mud_test.tscn`.
2. Select an animation phase in the **RotoPose v4** dock.
3. Drag hand, foot, weapon-tip, or body target gizmos in the viewport. Do not select or drag `Bone2D` nodes.
4. Use **Capture Pose** to add a semantic pose node.
5. Use **Export AI Data** for readable `.rotodata`, or **Bake Runtime** to create the compact `current_pose` playback track.

The runtime solver may change temporary bone rotations. It never changes rest transforms, authored bone positions/scales, hierarchy, or length. The original `res://scenes/mud_character.tscn`, its animations, and its SDF pipeline remain authoritative and untouched by v4.

## Migration

`RotoLegacyAnimationConverter` samples a legacy animation, captures semantic end-effector targets, and returns a `RotoPoseGraph`. The converter reads the legacy tracks but neither rewrites nor deletes them.
