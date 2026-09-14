@tool
class_name RotoBoneStandardRigBuilder
extends RefCounted

## Builds a compact side-view biped sized for 48x48 reference sprites.
## The rig is intentionally texture-free. Every Bone2D can be dragged/rotated
## with Godot's native Skeleton2D editor, and all rest transforms are initialized
## once at creation time.


static func create_standard_biped() -> Node2D:
	var rig := Node2D.new()
	rig.name = "RotoBoneRig"
	rig.set_meta("rotobone_standard_rig", true)

	var skeleton := Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	rig.add_child(skeleton)

	# Torso chain. Coordinates are centered around the hip/pelvis, matching the
	# default 48x48 reference pivot near (24, 40).
	var pelvis := _bone("pelvis", Vector2.ZERO, 0.0, 7.0, -PI * 0.5)
	skeleton.add_child(pelvis)

	var spine := _bone("torso", Vector2(0.0, -7.0), 0.0, 7.0, -PI * 0.5)
	pelvis.add_child(spine)

	var chest := _bone("chest", Vector2(0.0, -7.0), 0.0, 5.0, -PI * 0.5)
	spine.add_child(chest)

	var head := _bone("head", Vector2(0.0, -5.0), -PI * 0.5, 5.0, 0.0)
	chest.add_child(head)

	# Front arm. Slightly forward so the two side-view arm chains remain easy to
	# select even before the user begins tracing.
	var arm_front_upper := _bone("arm_front_upper", Vector2(0.5, -3.5), 0.35, 7.0, 0.0)
	chest.add_child(arm_front_upper)
	var arm_front_lower := _bone("arm_front_lower", Vector2(7.0, 0.0), 0.30, 7.0, 0.0)
	arm_front_upper.add_child(arm_front_lower)
	var hand_front := _bone("hand_front", Vector2(7.0, 0.0), -0.05, 3.5, 0.0)
	arm_front_lower.add_child(hand_front)

	# Back arm.
	var arm_back_upper := _bone("arm_back_upper", Vector2(-0.5, -3.0), -0.20, 7.0, 0.0)
	chest.add_child(arm_back_upper)
	var arm_back_lower := _bone("arm_back_lower", Vector2(7.0, 0.0), 0.55, 7.0, 0.0)
	arm_back_upper.add_child(arm_back_lower)
	var hand_back := _bone("hand_back", Vector2(7.0, 0.0), 0.05, 3.5, 0.0)
	arm_back_lower.add_child(hand_back)

	# Front leg.
	var leg_front_upper := _bone("leg_front_upper", Vector2(-1.8, 1.0), 1.28, 9.0, 0.0)
	pelvis.add_child(leg_front_upper)
	var leg_front_lower := _bone("leg_front_lower", Vector2(9.0, 0.0), -0.20, 9.0, 0.0)
	leg_front_upper.add_child(leg_front_lower)
	var foot_front := _bone("foot_front", Vector2(9.0, 0.0), -1.05, 5.0, 0.0)
	leg_front_lower.add_child(foot_front)

	# Back leg.
	var leg_back_upper := _bone("leg_back_upper", Vector2(1.8, 1.0), 1.72, 9.0, 0.0)
	pelvis.add_child(leg_back_upper)
	var leg_back_lower := _bone("leg_back_lower", Vector2(9.0, 0.0), -0.48, 9.0, 0.0)
	leg_back_upper.add_child(leg_back_lower)
	var foot_back := _bone("foot_back", Vector2(9.0, 0.0), -1.12, 5.0, 0.0)
	leg_back_lower.add_child(foot_back)

	# A lightweight player is included so the sample can immediately participate
	# in RotoBone's reference-frame sync workflow.
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = 1.0
	library.add_animation(&"trace_pose", animation)
	player.add_animation_library(&"", library)
	rig.add_child(player)

	return rig


static func _bone(
	semantic_name: String,
	local_position: Vector2,
	local_rotation: float,
	length: float,
	bone_angle: float
) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = semantic_name
	bone.position = local_position
	bone.rotation = local_rotation
	bone.set_autocalculate_length_and_angle(false)
	bone.set_length(length)
	bone.set_bone_angle(bone_angle)
	bone.rest = bone.transform
	bone.set_meta("rotobone_semantic", semantic_name)
	return bone
