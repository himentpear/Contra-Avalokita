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
	var viewport_overlay := scene.get_node_or_null("ReferenceOverlay") as RotoBoneViewportOverlay
	_check(viewport_overlay != null and viewport_overlay.show_rig_guides, "ReferenceOverlay shows depth and spine guides")
	var pose_guard := scene.get_node_or_null("RotoBonePoseGuard") as RotoBonePoseContractGuard
	_check(pose_guard != null and pose_guard.rotation_only, "rotation-only pose guard exists")
	var timeline := scene.get_node_or_null("KeyframeMarkerLayer") as RotoBoneTimelineOverlay
	_check(timeline != null, "KeyframeMarkerLayer exists")
	_check(timeline != null and timeline.profile != null and not timeline.profile.markers.is_empty(), "timeline renders marker data")
	var output_player := scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_check(output_player != null, "workspace AnimationPlayer exists")
	_check(output_player != null and output_player.has_animation_library(&"AssetActions"), "workspace AnimationPlayer exposes the AssetActions library")
	var placeholder_library := output_player.get_animation_library(&"AssetActions") if output_player != null else null
	_check(placeholder_library != null and placeholder_library.get_animation_list().size() == 36, "AssetActions contains 36 placeholder animations")
	_check(_count_type(scene, "Skeleton2D") == 1, "workspace contains exactly the source scene skeleton")
	var action_list := scene.get_node_or_null("ActionCatalogPanel/Margin/VBox/ActionList") as ItemList
	_check(action_list != null and action_list.item_count == 36, "test scene displays all 36 asset action folders")

	var adapter := Adapter.new()
	_check(adapter.bind_instance(mud_instance), "adapter detects CharacterBody2D, Skeleton2D, and AnimationPlayer")
	_check(adapter.character_body == mud_instance, "detected CharacterBody2D is the scene instance")
	_check(adapter.skeleton != null and mud_instance.get_path_to(adapter.skeleton) == NodePath("Visual/PoseRoot/Skeleton2D"), "existing skeleton path detected")
	_check(adapter.semantic_map.has("hips") and adapter.semantic_map.has("head"), "semantic bone map generated")
	_check(adapter.semantic_map.spine.bone == "Torso" and adapter.semantic_map.chest.bone == "Torso", "Torso owns the semantic spine and chest roles")
	_check(adapter.semantic_map.spine_lower_helper.bone == "SpineLower" and adapter.semantic_map.spine_upper_helper.bone == "SpineUpper", "renderer spine helpers are mapped separately")
	_check(_count_bones(adapter.skeleton) == 17, "all 17 existing bones detected")
	var checked_map: Variant = JSON.parse_string(FileAccess.get_file_as_string(Adapter.DEFAULT_MAP_PATH))
	_check(checked_map is Dictionary and checked_map.get("skeleton_path") == "Visual/PoseRoot/Skeleton2D", "stored bone map targets the source hierarchy")
	_check(checked_map is Dictionary and checked_map.get("visual_connections", []).size() == 1, "stored bone map declares the SpineUpper-to-Torso renderer bridge")

	pose_guard.capture_contract()
	var front_arm := adapter.skeleton.get_node("Pelvis/Torso/UpperArmFront") as Bone2D
	var back_arm := adapter.skeleton.get_node("Pelvis/Torso/UpperArmBack") as Bone2D
	var original_front_position: Vector2 = front_arm.position
	var original_front_scale: Vector2 = front_arm.scale
	var original_front_rest: Transform2D = front_arm.rest
	var original_front_length: float = front_arm.length
	var original_back_rotation: float = back_arm.rotation
	var authored_rotation: float = front_arm.rotation + 0.2
	front_arm.position += Vector2(8, 5)
	front_arm.scale = Vector2(1.4, 0.7)
	front_arm.rest = front_arm.rest.translated(Vector2(3, 0))
	front_arm.length += 9.0
	front_arm.rotation = authored_rotation
	var corrected := pose_guard.enforce_contract()
	_check(corrected.has("UpperArmFront"), "pose guard detects forbidden bone dragging")
	_check(front_arm.position == original_front_position and front_arm.scale == original_front_scale and front_arm.rest == original_front_rest and front_arm.length == original_front_length, "pose guard restores position, scale, rest, and length")
	_check(is_equal_approx(front_arm.rotation, authored_rotation), "pose guard preserves the authored front-bone rotation")
	_check(is_equal_approx(back_arm.rotation, original_back_rotation), "editing a front bone does not alter the back-bone pose")

	var workspace := Workspace.new()
	_check(workspace.load_catalog() == OK, "animation catalog loads")
	_check(workspace.asset_actions.size() == 36, "asset action catalog loads")
	var disk_folders := Array(DirAccess.get_directories_at("res://assets/2D-Pixel-Art-Character-Template/2D-Pixel-Art-Character-Template"))
	disk_folders.erase("Tilemap (Super Basic)")
	disk_folders.sort()
	var catalog_folders: Array[String] = []
	for action in workspace.asset_actions:
		catalog_folders.append(String(action.get("folder", "")))
		var reference_path := String(action.get("reference_sprite", ""))
		_check(FileAccess.file_exists(reference_path), "reference sprite exists for %s" % action.get("folder", ""))
		var texture := load(reference_path) as Texture2D
		var frame_width := int(action.get("frame_width", 0))
		var frame_height := int(action.get("frame_height", 0))
		_check(texture != null and frame_width > 0 and frame_height > 0 and texture.get_width() % frame_width == 0 and texture.get_height() % frame_height == 0, "sprite grid is valid for %s" % action.get("folder", ""))
	catalog_folders.sort()
	_check(catalog_folders == disk_folders, "catalog mirrors every action folder on disk")
	var placeholder_names: Array[String] = []
	var actions_by_folder := {}
	for action in workspace.asset_actions:
		actions_by_folder[String(action.get("folder", ""))] = action
	if placeholder_library != null:
		for placeholder_name in placeholder_library.get_animation_list():
			placeholder_names.append(String(placeholder_name))
	placeholder_names.sort()
	_check(placeholder_names == catalog_folders, "placeholder animation names mirror the asset catalog")
	if placeholder_library != null:
		for placeholder_name in placeholder_library.get_animation_list():
			var placeholder := placeholder_library.get_animation(placeholder_name)
			var action: Dictionary = actions_by_folder.get(String(placeholder_name), {})
			var texture := load(String(action.get("reference_sprite", ""))) as Texture2D
			var expected_frames := (texture.get_width() / int(action.get("frame_width", 48))) * (texture.get_height() / int(action.get("frame_height", 48)))
			_check(placeholder.length > 0.0 and is_equal_approx(placeholder.step, 1.0 / 12.0), "animation uses a 12 FPS grid: %s" % placeholder_name)
			_check(placeholder.get_marker_names().size() == expected_frames and placeholder.get_marker_names()[0] == &"F01", "every sprite frame has a named marker: %s" % placeholder_name)
			_check(placeholder.get_track_count() == 17, "all existing bones have editable tracks: %s" % placeholder_name)
			for track in placeholder.get_track_count():
				_check(String(placeholder.track_get_path(track)).ends_with(":rotation"), "placeholder track is rotation-only: %s" % placeholder_name)
				_check(placeholder.track_get_interpolation_type(track) == Animation.INTERPOLATION_CUBIC_ANGLE, "rotation interpolation is smooth and angle-safe: %s" % placeholder_name)
				_check(placeholder.track_get_key_count(track) == expected_frames, "every marked frame has a bone key: %s" % placeholder_name)
		_check(_animation_has_pose_variation(placeholder_library.get_animation(&"Walk")), "mapped placeholders sample real source pose variation")
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
	var sword_stab_index := _asset_index(workspace.asset_actions, "Sword Stab")
	workspace.select_asset_action(sword_stab_index)
	_check(workspace.active_profile.animation_name == &"thrust", "Sword Stab maps to the thrust profile")
	_check(workspace.asset_actions[sword_stab_index].source_animation == "Blade/Attack_2", "Sword Stab maps to Blade/Attack_2")
	var wall_slide_index := _asset_index(workspace.asset_actions, "Wall Slide")
	workspace.select_asset_action(wall_slide_index)
	_check(workspace.active_profile.animation_name == &"wall_slide", "Wall Slide maps to the wall_slide profile")
	var dash_index := _asset_index(workspace.asset_actions, "Dash")
	_check(workspace.asset_actions[dash_index].mapping == "excluded" and workspace.asset_actions[dash_index].canonical_action == "", "excluded folders do not expand the v3 action set")

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
			_check(animation.track_get_interpolation_type(track) == Animation.INTERPOLATION_CUBIC_ANGLE, "baked rotation interpolation is smooth")

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


func _asset_index(actions: Array[Dictionary], folder: String) -> int:
	for index in actions.size():
		if actions[index].get("folder", "") == folder:
			return index
	return -1


func _animation_has_pose_variation(animation: Animation) -> bool:
	for track in animation.get_track_count():
		if animation.track_get_key_count(track) < 2:
			continue
		var first_value := float(animation.track_get_key_value(track, 0))
		for key_index in range(1, animation.track_get_key_count(track)):
			if not is_equal_approx(first_value, float(animation.track_get_key_value(track, key_index))):
				return true
	return false


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
