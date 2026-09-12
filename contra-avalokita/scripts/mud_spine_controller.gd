class_name MudSpineController
extends RefCounted

## Procedural spine deformation controller.
## Manages SpineLower and SpineUpper deformation bones to create natural curvature,
## bowing towards the wall during wall actions while remaining straight during normal movement.

var spine_wall_weight := 0.0

func update(character: MudCharacter, pelvis: Bone2D, torso: Bone2D, spine_lower: Bone2D, spine_upper: Bone2D, delta: float) -> void:
	if not is_instance_valid(character) or not is_instance_valid(pelvis) or not is_instance_valid(torso):
		return
	if not is_instance_valid(spine_lower) or not is_instance_valid(spine_upper):
		return

	var action: StringName = character.wall_action
	var target_weight := 0.0

	match action:
		&"WallHang":
			target_weight = 1.0
		&"WallSlide":
			# Relaxed spine, slightly elongated with micro-compression from scrape
			var scrape: float = character.wall_slide_scrape_offset
			target_weight = 0.75 + scrape * 0.05
		&"WallPush":
			# Compressed arch preparing for spring release
			var push_p := clampf(character.wall_action_time / maxf(character.wall_push_duration, 0.001), 0.0, 1.0)
			target_weight = lerpf(1.0, 1.25, push_p)
		&"WallRelease":
			# Fast unroll back to air pose
			var rel_p := clampf(character.wall_action_time / maxf(character.wall_release_duration, 0.001), 0.0, 1.0)
			target_weight = lerpf(1.0, 0.0, rel_p)
		_:
			target_weight = 0.0

	var blend_rate := 0.10
	if action == &"WallRelease":
		blend_rate = 0.14
	elif action == &"None":
		blend_rate = 0.12

	if delta <= 0.0:
		spine_wall_weight = target_weight
	else:
		spine_wall_weight = move_toward(spine_wall_weight, target_weight, delta / blend_rate)

	# Torso bone position in Pelvis local space:
	var chest_local := torso.position

	# Base linear interpolation along the Pelvis -> Chest line:
	# SpineLower at 1/3, SpineUpper at 2/3:
	var base_lower := chest_local * 0.333
	var base_upper := chest_local * 0.667

	# Wall arch curvature:
	# In Pelvis local space (scaled by visual.scale.x = facing):
	# +X is toward the wall, -X is away from the wall.
	# The waist (SpineLower) arches outward/away from the wall (-X) creating the authentic climbing posture:
	var curve_lower := -2.4 * spine_wall_weight
	var curve_upper := -1.0 * spine_wall_weight

	# SpineLower is child of Pelvis:
	spine_lower.position = Vector2(base_lower.x + curve_lower, base_lower.y)

	# SpineUpper is child of SpineLower:
	# Relative position from SpineLower to SpineUpper:
	var diff := base_upper - base_lower
	spine_upper.position = Vector2(diff.x + (curve_upper - curve_lower), diff.y)
