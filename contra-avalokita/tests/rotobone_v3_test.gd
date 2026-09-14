extends SceneTree

const Adapter := preload("res://addons/rotobone/v3/core/mud_character_adapter.gd")
const Workspace := preload("res://addons/rotobone/v3/core/rotobone_workspace.gd")
const Baker := preload("res://addons/rotobone/v3/animation/pose_baker.gd")
const Marker := preload("res://addons/rotobone/v3/animation/keyframe_marker.gd")

const EXPECTED_ACTIONS := ["idle", "walk", "run", "jump", "fall", "land", "wall_slide", "slash", "thrust", "roll", "hurt", "death"]
const FORBIDDEN_ACTIONS := ["shooting", "ledge_grab", "ledge_climb", "air_spin", "dash", "slide", "punch", "jab"]

var _failures: Array[String] = []


func _initialize() -> void:
	var player_input := root.get_node_or_null("PlayerInput")
	if player_input != null:
		player_input.process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://tests/rotobone_mud_character_test.tscn") as PackedScene
	_check(packed != null, "root test scene loads")
	if packed == null:
		_finish()
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var mud_instance := scene.get_node_or_null("MudCharacterInstance")
	_check(mud_instance != null, "MudCharacterInstance exists")
	_check(mud_instance != null and mud_instance.scene_file_path == Adapter.TEMPLATE_PATH, "test uses mud_character PackedScene instance")
	_check(scene.get_node_or_null("RotoBoneAnchor") is Marker2D, "RotoBoneAnchor exists")
	_check(scene.get_node_or_null("ReferenceOverlay") is RotoBoneViewportOverlay, "ReferenceOverlay exists")
	var timeline := scene.get_node_or_null("KeyframeMarkerLayer") as RotoBoneTimelineOverlay
	_check(timeline != null, "KeyframeMarkerLayer exists")
	_check(timeline != null and timeline.profile != null and not timeline.profile.markers.is_empty(), "timeline renders marker data")
	var output_player := scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_check(output_player != null, "workspace AnimationPlayer exists")
	_check(_count_type(scene, "Skeleton2D") == 1, "workspace contains exactly the source scene skeleton")

	var adapter := Adapter.new()
	_check(adapter.bind_instance(mud_instance), "adapter detects CharacterBody2D, Skeleton2D, and AnimationPlayer")
	_check(adapter.character_body == mud_instance, "detected CharacterBody2D is the scene instance")
	_check(adapter.skeleton != null and mud_instance.get_path_to(adapter.skeleton) == NodePath("Visual/PoseRoot/Skeleton2D"), "existing skeleton path detected")
	_check(adapter.semantic_map.has("hips") and adapter.semantic_map.has("head"), "semantic bone map generated")
	_check(_count_bones(adapter.skeleton) == 17, "all 17 existing bones detected")
	var checked_map: Variant = JSON.parse_string(FileAccess.get_file_as_string(Adapter.DEFAULT_MAP_PATH))
	_check(checked_map is Dictionary and checked_map.get("skeleton_path") == "Visual/PoseRoot/Skeleton2D", "stored bone map targets the source hierarchy")

	var workspace := Workspace.new()
	_check(workspace.load_catalog() == OK, "animation catalog loads")
	var names: Array[String] = []
	for profile in workspace.profiles:
		names.append(String(profile.animation_name))
	_check(names == EXPECTED_ACTIONS, "catalog contains only the requested action set")
	for forbidden in FORBIDDEN_ACTIONS:
		_check(not names.has(forbidden), "catalog excludes %s" % forbidden)
	_check(workspace.profiles[1].markers.size() >= 4, "walk profile exposes timeline markers")
	_check(Marker.SYMBOLS[Marker.MarkerType.CONTACT] == "○" and Marker.SYMBOLS[Marker.MarkerType.IMPACT] == "✕", "marker symbols are stable")
	for index in 9:
		_check(adapter.available_animations().has(String(workspace.profiles[index].source_animation)), "source clip exists for %s" % workspace.profiles[index].animation_name)

	var snapshot := _snapshot_skeleton(adapter.skeleton)
	var pelvis := adapter.skeleton.get_node("Pelvis") as Bone2D
	pelvis.rotation += 0.125
	var inserted := Baker.new().bake_pose(output_player, adapter.skeleton, &"idle", 0.125)
	_check(inserted == 17, "Bake Pose creates one rotation key per existing bone")
	_check(_skeleton_contract_unchanged(adapter.skeleton, snapshot), "Bake Pose preserves rest, length, hierarchy, position, and scale")
	var animation := output_player.get_animation(&"RotoBone/idle")
	_check(animation != null and animation.get_track_count() == 17, "baked animation is isolated in the wrapper player")
	if animation != null:
		for track in animation.get_track_count():
			var path := String(animation.track_get_path(track))
			_check(path.ends_with(":rotation") and not ":rest" in path and not ":scale" in path, "baked track is rotation-only: %s" % path)

	pelvis.rotation = 0.0
	adapter.clear()
	workspace.profiles.clear()
	workspace.active_profile = null
	root.remove_child(scene)
	scene.free()
	call_deferred("_finish")


func _snapshot_skeleton(skeleton: Skeleton2D) -> Dictionary:
	var result := {}
	for bone in _bones(skeleton):
		result[String(skeleton.get_path_to(bone))] = {
			"rest": bone.rest,
			"length": bone.length,
			"parent": String(skeleton.get_path_to(bone.get_parent())),
			"position": bone.position,
			"scale": bone.scale,
		}
	return result


func _skeleton_contract_unchanged(skeleton: Skeleton2D, snapshot: Dictionary) -> bool:
	for bone in _bones(skeleton):
		var state: Dictionary = snapshot.get(String(skeleton.get_path_to(bone)), {})
		if state.is_empty() or bone.rest != state.rest or bone.length != state.length:
			return false
		if String(skeleton.get_path_to(bone.get_parent())) != state.parent or bone.position != state.position or bone.scale != state.scale:
			return false
	return true


func _count_bones(skeleton: Skeleton2D) -> int:
	return _bones(skeleton).size()


func _count_type(node: Node, type_name: StringName) -> int:
	var total := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		total += _count_type(child, type_name)
	return total


func _bones(skeleton: Skeleton2D) -> Array[Bone2D]:
	var result: Array[Bone2D] = []
	_collect_bones(skeleton, result)
	return result


func _collect_bones(node: Node, result: Array[Bone2D]) -> void:
	for child in node.get_children():
		if child is Bone2D:
			result.append(child as Bone2D)
		_collect_bones(child, result)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("RotoBone v3 test passed")
		quit(0)
	else:
		push_error("RotoBone v3 test failed: %s" % ", ".join(_failures))
		quit(1)
