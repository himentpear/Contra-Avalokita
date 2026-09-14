extends SceneTree

const Adapter := preload("res://addons/rotobone/v4/core/mud_character_pose_adapter.gd")
const Graph := preload("res://addons/rotobone/v4/core/pose_graph.gd")
const PoseNode := preload("res://addons/rotobone/v4/core/pose_node.gd")
const Pose := preload("res://addons/rotobone/v4/core/roto_pose.gd")
const Solver := preload("res://addons/rotobone/v4/core/pose_solver.gd")
const SemanticTarget := preload("res://addons/rotobone/v4/core/semantic_target.gd")
const Controller := preload("res://addons/rotobone/v4/runtime/pose_controller.gd")
const IKBridge := preload("res://addons/rotobone/v4/runtime/ik_bridge.gd")
const Runtime := preload("res://addons/rotobone/v4/runtime/animation_runtime.gd")
const Converter := preload("res://addons/rotobone/v4/runtime/legacy_animation_converter.gd")
const Exporter := preload("res://addons/rotobone/v4/export/ai_pose_exporter.gd")
const Writer := preload("res://addons/rotobone/v4/export/pose_json_writer.gd")
const ViewportEditor := preload("res://addons/rotobone/v4/editor/pose_viewport.gd")
const Gizmo := preload("res://addons/rotobone/v4/editor/target_gizmo.gd")
const TimelineMarker := preload("res://addons/rotobone/v4/editor/timeline_marker.gd")
const Dock := preload("res://addons/rotobone/v4/editor/pose_editor_dock.gd")

var failures := 0


func _initialize() -> void:
	var player_input := root.get_node_or_null("PlayerInput")
	if player_input != null:
		player_input.process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://tests/rotopose_mud_test.tscn") as PackedScene
	_check(packed != null, "v4 test scene loads")
	if packed == null:
		_finish()
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var mud := scene.get_node("MudCharacter")
	_check(mud.scene_file_path == "res://scenes/mud_character.tscn", "test scene instances mud_character without copying it")
	var skeleton := mud.get_node("Visual/PoseRoot/Skeleton2D") as Skeleton2D
	_check(skeleton != null, "existing Skeleton2D is used as runtime execution layer")
	_check(mud.get_node_or_null("Visual/MudBodyRenderer") != null, "existing SDF renderer remains present")

	var adapter := Adapter.new()
	_check(adapter.detect(mud), "Mud Character adapter detects skeleton and AnimationPlayer")
	_check(adapter.semantic_map["hand_r"].ends_with("HandFront"), "semantic hand_r maps to HandFront")
	_check(adapter.semantic_map["body"].ends_with("Torso"), "semantic body maps to Torso")
	_check(adapter.semantic_map.size() >= 15, "adapter generates complete limb semantic mapping")

	var controller := scene.get_node("PoseController") as RotoPoseController
	var viewport := scene.get_node("PoseViewport") as RotoPoseViewport
	_check(controller != null and viewport != null, "target editor and runtime controller are present")
	_check(viewport.get_child_count() >= 6, "viewport exposes semantic target gizmos instead of bone handles")
	_check(viewport.reference_texture != null and viewport.reference_hframes == 6, "viewport displays the six-frame Sword Attack reference")
	var original_hand_target := viewport.pose.get_target(&"hand_r")
	_check(viewport.begin_target_drag(original_hand_target), "target gizmo begins a drag without selecting Bone2D")
	_check(viewport.drag_active_target(original_hand_target + Vector2(3, -2)), "target gizmo updates through target-space dragging")
	viewport.end_target_drag()
	_check(viewport.pose.get_target(&"hand_r").is_equal_approx(original_hand_target + Vector2(3, -2)), "drag writes the semantic hand target")
	viewport.pose.set_target(&"hand_r", original_hand_target)
	var before := _bone_contract(skeleton)
	controller.current_pose = viewport.pose
	var after := _bone_contract(skeleton)
	_check(before == after, "runtime solver preserves rest, length, hierarchy, position, and scale")

	var player := scene.get_node("AnimationPlayer") as AnimationPlayer
	var animation := player.get_animation(&"attack_slash")
	_check(animation != null, "attack_slash playback container exists")
	_check(animation.get_track_count() == 1, "AnimationPlayer uses one current_pose track")
	_check(String(animation.track_get_path(0)) == "PoseController:current_pose", "playback track targets RotoPoseController.current_pose")
	_check(animation.track_get_key_count(0) == 4, "attack graph has start, windup, impact, and recovery poses")
	_check(not String(animation.track_get_path(0)).contains("Bone"), "playback contains no Bone2D transform tracks")
	player.play(&"attack_slash")
	player.seek(0.22, true)
	_check(controller.current_pose != null and controller.current_pose.tags.has("impact"), "impact pose is selected through AnimationPlayer")

	var graph := _graph_from_animation(animation)
	var exported := Exporter.new().graph_to_dictionary(graph)
	var exported_text := JSON.stringify(exported)
	_check(exported["intent"] == "melee_attack", "AI export describes animation intent")
	_check(exported["phases"].size() == 4, "AI export contains readable phases")
	_check(not exported_text.contains("Bone2D") and not exported_text.contains(":rotation"), "AI export contains no raw bone rotation tracks")
	var export_path := "user://rotobone_v4_test.rotodata"
	_check(Exporter.new().export_graph(graph, export_path) == OK and FileAccess.file_exists(export_path), ".rotodata writer exports valid data")

	var source_animation: StringName = adapter.animation_player.get_animation_list()[0] if adapter.animation_player.get_animation_list().size() > 0 else StringName()
	var converted := Converter.new().convert(adapter.animation_player, skeleton, adapter.semantic_map, source_animation, PackedFloat32Array([0.0, 0.1]))
	_check(converted.nodes.size() == 2, "legacy converter samples old bone animation into pose nodes")
	var converted_playback := Converter.new().build_playback_animation(converted, NodePath("PoseController"))
	_check(converted_playback.get_track_count() == 1, "legacy converter output has only one pose track")

	var profile := _read_json("res://addons/rotobone/v4/presets/mud_character_pose_profile.json")
	_check(profile.get("character", "") == "res://scenes/mud_character.tscn", "pose profile targets the existing Mud Character")
	_check(profile.get("editing_contract", {}).get("forbidden", []).has("rest"), "pose profile forbids rest-pose editing")
	_check(FileAccess.file_exists("res://addons/rotobone/v4/editor/rotobone_v4_plugin.gd"), "v4 editor plugin exists")
	_check(FileAccess.file_exists("res://addons/rotobone/v4/runtime/animation_runtime.gd"), "v4 animation runtime exists")
	_check(FileAccess.file_exists("res://addons/rotobone/v4/runtime/legacy_animation_converter.gd"), "legacy migration tool exists")
	var marker := TimelineMarker.new()
	marker.type = RotoTimelineMarker.Type.IMPACT
	_check(marker.symbol() == "✕", "timeline marker symbols include IMPACT")
	root.remove_child(scene)
	scene.free()
	_finish()


func _graph_from_animation(animation: Animation) -> RotoPoseGraph:
	var graph := Graph.new()
	graph.graph_name = &"attack_slash"
	graph.intent = "melee_attack"
	for index in animation.track_get_key_count(0):
		var pose := animation.track_get_key_value(0, index) as RotoPose
		var node := PoseNode.new()
		node.node_id = pose.pose_name
		node.display_name = String(pose.pose_name).capitalize()
		node.pose = pose
		node.meaning = "weapon collision" if pose.tags.has("impact") else String(pose.pose_name).replace("_", " ")
		node.marker_type = RotoPoseNode.MarkerType.IMPACT if pose.tags.has("impact") else RotoPoseNode.MarkerType.BREAKDOWN
		graph.add_node(node)
	return graph


func _bone_contract(skeleton: Skeleton2D) -> Dictionary:
	var result := {}
	for node in skeleton.find_children("*", "Bone2D", true, false):
		var bone := node as Bone2D
		result[String(skeleton.get_path_to(bone))] = [bone.rest, bone.length, bone.position, bone.scale, String(bone.get_parent().name)]
	return result


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures == 0:
		print("RotoBone v4 test passed")
		quit(0)
	else:
		push_error("RotoBone v4 test failed: %d failure(s)" % failures)
		quit(1)
