@tool
class_name RotoBonePoseBaker
extends RefCounted

const OUTPUT_LIBRARY := "RotoBone"


func bake_pose(
	animation_player: AnimationPlayer,
	skeleton: Skeleton2D,
	animation_name: StringName,
	time: float,
	include_root_position := false,
	root_node: Node2D = null
) -> int:
	if animation_player == null or skeleton == null or animation_name.is_empty():
		return 0
	var animation := _get_or_create_animation(animation_player, animation_name)
	var animation_root := animation_player.get_node_or_null(animation_player.root_node)
	if animation_root == null:
		animation_root = animation_player.get_parent()
	if animation_root == null:
		return 0

	var inserted := 0
	for bone in _collect_bones(skeleton):
		var path := NodePath(String(animation_root.get_path_to(bone)) + ":rotation")
		_insert_value(animation, path, maxf(0.0, time), bone.rotation)
		inserted += 1
	if include_root_position and root_node != null:
		var root_path := NodePath(String(animation_root.get_path_to(root_node)) + ":position")
		_insert_value(animation, root_path, maxf(0.0, time), root_node.position)
		inserted += 1
	animation.length = maxf(animation.length, maxf(0.001, time))
	animation.emit_changed()
	return inserted


func _get_or_create_animation(player: AnimationPlayer, animation_name: StringName) -> Animation:
	var library: AnimationLibrary
	if player.has_animation_library(OUTPUT_LIBRARY):
		library = player.get_animation_library(OUTPUT_LIBRARY)
	else:
		library = AnimationLibrary.new()
		player.add_animation_library(OUTPUT_LIBRARY, library)
	if library.has_animation(animation_name):
		return library.get_animation(animation_name)
	var animation := Animation.new()
	animation.resource_name = String(animation_name)
	library.add_animation(animation_name, animation)
	return animation


func _insert_value(animation: Animation, path: NodePath, time: float, value: Variant) -> void:
	var track := animation.find_track(path, Animation.TYPE_VALUE)
	if track < 0:
		track = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, path)
		var interpolation := Animation.INTERPOLATION_CUBIC_ANGLE if String(path).ends_with(":rotation") else Animation.INTERPOLATION_CUBIC
		animation.track_set_interpolation_type(track, interpolation)
	animation.track_insert_key(track, time, value)


func _collect_bones(skeleton: Skeleton2D) -> Array[Bone2D]:
	var bones: Array[Bone2D] = []
	_collect_bones_recursive(skeleton, bones)
	return bones


func _collect_bones_recursive(node: Node, bones: Array[Bone2D]) -> void:
	for child in node.get_children():
		if child is Bone2D:
			bones.append(child as Bone2D)
		_collect_bones_recursive(child, bones)
