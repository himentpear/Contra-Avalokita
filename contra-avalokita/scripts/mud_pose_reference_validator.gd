@tool
class_name MudPoseReferenceValidator
extends Node
## Editor guard for the immutable Bone2D reference pose.
## Never author animation by saving preview transforms into Bone2D scene nodes.

@export_node_path("Skeleton2D") var skeleton_path := NodePath("../Visual/PoseRoot/Skeleton2D")
@export_node_path("AnimationPlayer") var animation_player_path := NodePath("../AnimationPlayer")
@export var validation_enabled := true:
	set(value):
		validation_enabled = value
		update_configuration_warnings()

func _ready() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
	elif OS.is_debug_build():
		validate_reference_pose(true)

func _get_configuration_warnings() -> PackedStringArray:
	if not validation_enabled: return PackedStringArray()
	return PackedStringArray(validate_reference_pose(false))

func validate_reference_pose(report_errors := true) -> Array[String]:
	var failures: Array[String] = []
	var skeleton := get_node_or_null(skeleton_path) as Skeleton2D
	var player := get_node_or_null(animation_player_path) as AnimationPlayer
	if not skeleton:
		failures.append("[PoseValidation] Skeleton2D not found: %s" % skeleton_path)
		return _report(failures,report_errors)
	if not player or not player.has_animation(&"RESET"):
		failures.append("[PoseValidation] Complete RESET animation is missing")
		return _report(failures,report_errors)
	var reset := player.get_animation(&"RESET")
	var animation_root := player.get_node_or_null(player.root_node)
	var pose_root := skeleton.get_parent() as Node2D
	if pose_root:
		_check_property(failures,reset,animation_root,pose_root,"position",Vector2.ZERO,pose_root.position)
		_check_property(failures,reset,animation_root,pose_root,"rotation",0.0,pose_root.rotation)
		_check_property(failures,reset,animation_root,pose_root,"scale",Vector2.ONE,pose_root.scale)
	for child in skeleton.find_children("*","Bone2D",true,false):
		var bone := child as Bone2D
		var reference: Transform2D = bone.rest
		_check_property(failures,reset,animation_root,bone,"position",reference.origin,bone.position)
		_check_property(failures,reset,animation_root,bone,"rotation",reference.get_rotation(),bone.rotation)
		_check_property(failures,reset,animation_root,bone,"scale",reference.get_scale(),bone.scale)
	return _report(failures,report_errors)

func _check_property(failures: Array[String], reset: Animation, animation_root: Node, pose_node: Node2D, property: String, expected: Variant, found: Variant) -> void:
	if not animation_root:
		failures.append("[PoseValidation] AnimationPlayer root is invalid")
		return
	var track_path := NodePath("%s:%s" % [animation_root.get_path_to(pose_node),property])
	var track := reset.find_track(track_path,Animation.TYPE_VALUE)
	if track < 0 or reset.track_get_key_count(track) == 0:
		failures.append("[PoseValidation] RESET missing %s" % track_path)
		return
	var reset_value: Variant = reset.track_get_key_value(track,0)
	if not _approximately_equal(reset_value,expected):
		failures.append("[PoseValidation] RESET mismatch: %s.%s expected %s, found %s" % [pose_node.name,property,expected,reset_value])
	if not _approximately_equal(found,expected):
		failures.append("[PoseValidation] Reference pose drift: %s.%s expected %s, found %s" % [pose_node.name,property,expected,found])

func _approximately_equal(a: Variant, b: Variant) -> bool:
	if a is Vector2 and b is Vector2: return a.is_equal_approx(b)
	if a is float or a is int: return is_equal_approx(float(a),float(b))
	return a == b

func _report(failures: Array[String], report_errors: bool) -> Array[String]:
	if report_errors:
		for failure in failures: push_error(failure)
	return failures
