@tool
class_name RotoPoseSolver
extends RefCounted

var skeleton: Skeleton2D
var semantic_map: Dictionary = {}


func configure(target_skeleton: Skeleton2D, mapping: Dictionary) -> void:
	skeleton = target_skeleton
	semantic_map = mapping.duplicate(true)


func apply_pose(pose: RotoPose) -> bool:
	if skeleton == null or pose == null:
		return false
	_apply_body_lean(pose)
	_solve_limb(pose, &"hand_r", &"arm_r", &"forearm_r", -1.0)
	_solve_limb(pose, &"hand_l", &"arm_l", &"forearm_l", 1.0)
	_solve_limb(pose, &"foot_r", &"leg_r", &"shin_r", 1.0)
	_solve_limb(pose, &"foot_l", &"leg_l", &"shin_l", -1.0)
	_apply_weapon_direction(pose)
	_apply_rotation_hints(pose)
	return true


func _apply_body_lean(pose: RotoPose) -> void:
	var body := _bone(&"body")
	if body != null:
		body.rotation = deg_to_rad(pose.body_lean)


func _solve_limb(pose: RotoPose, target_key: StringName, upper_key: StringName, lower_key: StringName, default_bend: float) -> void:
	if not pose.has_target(target_key):
		return
	var upper := _bone(upper_key)
	var lower := _bone(lower_key)
	if upper == null or lower == null:
		return
	var target_global := skeleton.to_global(pose.get_target(target_key))
	var origin := upper.global_position
	var delta := target_global - origin
	var upper_length := maxf(upper.length, lower.position.length())
	var lower_length := maxf(lower.length, 0.001)
	if upper_length <= 0.001:
		upper_length = 12.0
	if lower_length <= 0.001:
		lower_length = 12.0
	var distance := clampf(delta.length(), 0.001, upper_length + lower_length - 0.001)
	var bend := float(pose.rotation_hints.get(String(target_key) + "_bend", default_bend))
	var shoulder_offset := acos(clampf((upper_length * upper_length + distance * distance - lower_length * lower_length) / (2.0 * upper_length * distance), -1.0, 1.0))
	var world_upper := delta.angle() + signf(bend) * shoulder_offset
	upper.rotation = world_upper - upper.get_parent().global_rotation
	var elbow_angle := acos(clampf((upper_length * upper_length + lower_length * lower_length - distance * distance) / (2.0 * upper_length * lower_length), -1.0, 1.0))
	lower.rotation = -signf(bend) * (PI - elbow_angle)


func _apply_weapon_direction(pose: RotoPose) -> void:
	if not pose.has_target(&"weapon_tip"):
		return
	var hand := _bone(&"hand_r")
	if hand == null:
		return
	var tip_global := skeleton.to_global(pose.get_target(&"weapon_tip"))
	var parent := hand.get_parent() as Node2D
	if parent != null:
		hand.rotation = (tip_global - hand.global_position).angle() - parent.global_rotation


func _apply_rotation_hints(pose: RotoPose) -> void:
	for semantic_name in pose.rotation_hints:
		if String(semantic_name).ends_with("_bend"):
			continue
		var bone := _bone(StringName(semantic_name))
		if bone != null:
			bone.rotation = deg_to_rad(float(pose.rotation_hints[semantic_name]))


func _bone(semantic_name: StringName) -> Bone2D:
	if skeleton == null:
		return null
	var path := NodePath(String(semantic_map.get(String(semantic_name), "")))
	return skeleton.get_node_or_null(path) as Bone2D if not path.is_empty() else null
