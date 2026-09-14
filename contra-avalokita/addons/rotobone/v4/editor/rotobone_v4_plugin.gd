@tool
extends EditorPlugin

const Adapter := preload("res://addons/rotobone/v4/core/mud_character_pose_adapter.gd")
const Dock := preload("res://addons/rotobone/v4/editor/pose_editor_dock.gd")
const Exporter := preload("res://addons/rotobone/v4/export/ai_pose_exporter.gd")
const Converter := preload("res://addons/rotobone/v4/runtime/legacy_animation_converter.gd")

var _adapter := Adapter.new()
var _dock_host: EditorDock
var _dock: RotoPoseEditorDock
var _graph: RotoPoseGraph
var _active_pose_index := 0


func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.pose_selected.connect(_on_pose_selected)
	_dock.capture_requested.connect(_on_capture_pose)
	_dock.export_requested.connect(_on_export_ai_data)
	_dock.bake_requested.connect(_on_bake_runtime)
	_dock.target_visibility_changed.connect(_on_target_visibility_changed)
	_dock_host = EditorDock.new()
	_dock_host.title = "RotoPose v4"
	_dock_host.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	_dock_host.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	_dock_host.add_child(_dock)
	add_dock(_dock_host)
	if not scene_changed.is_connected(_on_scene_changed):
		scene_changed.connect(_on_scene_changed)
	call_deferred("_refresh")


func _exit_tree() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if _dock_host != null:
		remove_dock(_dock_host)
		_dock_host.queue_free()
	_adapter.clear()


func _on_scene_changed(_root: Node) -> void:
	_refresh()


func _refresh() -> void:
	var root := EditorInterface.get_edited_scene_root()
	var detected := root != null and _adapter.detect(root)
	_dock.set_character_status(detected)
	var viewport := _find_pose_viewport(root)
	var player := _find_wrapper_player(root)
	if player != null and player.has_animation(&"attack_slash"):
		_graph = _graph_from_animation(player.get_animation(&"attack_slash"))
	elif viewport != null and viewport.pose != null:
		_graph = _graph_from_pose(viewport.pose)
	elif _graph == null:
		_graph = _default_attack_graph()
	_dock.set_graph(_graph)
	_apply_selected_pose()


func _on_pose_selected(index: int) -> void:
	_active_pose_index = index
	_apply_selected_pose()


func _apply_selected_pose() -> void:
	var viewport := _find_pose_viewport(EditorInterface.get_edited_scene_root())
	var nodes := _graph.sorted_nodes() if _graph != null else []
	if viewport != null and _active_pose_index >= 0 and _active_pose_index < nodes.size():
		viewport.pose = nodes[_active_pose_index].pose


func _on_capture_pose() -> void:
	var viewport := _find_pose_viewport(EditorInterface.get_edited_scene_root())
	if viewport == null or viewport.pose == null:
		_dock.set_status("Add a RotoPoseViewport to capture semantic targets.")
		return
	var pose := viewport.pose.duplicate(true) as RotoPose
	pose.pose_name = StringName("pose_%02d" % _graph.nodes.size())
	var node := RotoPoseNode.new()
	node.node_id = pose.pose_name
	node.display_name = String(pose.pose_name).capitalize()
	node.pose = pose
	if not _graph.nodes.is_empty():
		_graph.nodes[-1].next_nodes = PackedStringArray([String(node.node_id)])
	_graph.add_node(node)
	_dock.set_graph(_graph)
	_dock.set_status("Captured semantic targets; no Bone2D track was created.")


func _on_export_ai_data() -> void:
	var directory := ProjectSettings.globalize_path("res://artifacts/rotobone")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := "res://artifacts/rotobone/%s.rotodata" % String(_graph.graph_name)
	var error := Exporter.new().export_graph(_graph, path)
	_dock.set_status("Exported %s" % path if error == OK else "Export failed: %s" % error_string(error))


func _on_bake_runtime() -> void:
	var root := EditorInterface.get_edited_scene_root()
	var player := _find_wrapper_player(root)
	var controller := _find_pose_controller(root)
	if player == null or controller == null:
		_dock.set_status("Test scene needs a wrapper AnimationPlayer and RotoPoseController.")
		return
	var library := player.get_animation_library(&"")
	if library == null:
		library = AnimationLibrary.new()
		player.add_animation_library(&"", library)
	var animation := Converter.new().build_playback_animation(_graph, root.get_path_to(controller))
	if library.has_animation(_graph.graph_name):
		library.remove_animation(_graph.graph_name)
	library.add_animation(_graph.graph_name, animation)
	EditorInterface.mark_scene_as_unsaved()
	_dock.set_status("Baked one current_pose track (%d pose keys)." % animation.track_get_key_count(0))


func _on_target_visibility_changed(target_name: StringName, enabled: bool) -> void:
	var viewport := _find_pose_viewport(EditorInterface.get_edited_scene_root())
	if viewport == null:
		return
	var targets := Array(viewport.enabled_targets)
	if enabled and not targets.has(String(target_name)):
		targets.append(String(target_name))
	elif not enabled:
		targets.erase(String(target_name))
	viewport.enabled_targets = PackedStringArray(targets)
	viewport.pose = viewport.pose


func _find_pose_viewport(node: Node) -> RotoPoseViewport:
	if node == null:
		return null
	if node is RotoPoseViewport:
		return node
	for child in node.get_children():
		var found := _find_pose_viewport(child)
		if found != null:
			return found
	return null


func _find_pose_controller(node: Node) -> RotoPoseController:
	if node == null:
		return null
	if node is RotoPoseController:
		return node
	for child in node.get_children():
		var found := _find_pose_controller(child)
		if found != null:
			return found
	return null


func _find_wrapper_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	for child in root.get_children():
		if child is AnimationPlayer and child != _adapter.animation_player:
			return child
	return null


func _graph_from_pose(pose: RotoPose) -> RotoPoseGraph:
	var graph := RotoPoseGraph.new()
	graph.graph_name = &"attack_slash"
	graph.intent = "melee_attack"
	var node := RotoPoseNode.new()
	node.node_id = pose.pose_name
	node.display_name = String(pose.pose_name).capitalize()
	node.pose = pose
	graph.add_node(node)
	return graph


func _graph_from_animation(animation: Animation) -> RotoPoseGraph:
	var graph := RotoPoseGraph.new()
	graph.graph_name = &"attack_slash"
	graph.intent = "melee_attack"
	if animation == null or animation.get_track_count() == 0:
		return graph
	for index in animation.track_get_key_count(0):
		var pose := animation.track_get_key_value(0, index) as RotoPose
		if pose == null:
			continue
		var node := RotoPoseNode.new()
		node.node_id = pose.pose_name
		node.display_name = String(pose.pose_name).capitalize()
		node.pose = pose
		node.marker_type = RotoPoseNode.MarkerType.IMPACT if pose.tags.has("impact") else (
			RotoPoseNode.MarkerType.EXTREME if pose.tags.has("windup") else RotoPoseNode.MarkerType.BREAKDOWN
		)
		node.meaning = "weapon collision" if pose.tags.has("impact") else String(pose.pose_name).replace("_", " ")
		if not graph.nodes.is_empty():
			graph.nodes[-1].next_nodes = PackedStringArray([String(node.node_id)])
		graph.add_node(node)
	return graph


func _default_attack_graph() -> RotoPoseGraph:
	var graph := RotoPoseGraph.new()
	graph.graph_name = &"attack_slash"
	graph.intent = "melee_attack"
	for spec in [
		["start", 0.0, RotoPoseNode.MarkerType.CONTACT, "preparation"],
		["windup", 0.15, RotoPoseNode.MarkerType.EXTREME, "maximum force"],
		["impact", 0.22, RotoPoseNode.MarkerType.IMPACT, "weapon collision"],
		["recover", 0.40, RotoPoseNode.MarkerType.BREAKDOWN, "recovery"],
	]:
		var pose := RotoPose.new()
		pose.pose_name = StringName(spec[0])
		pose.time = spec[1]
		var node := RotoPoseNode.new()
		node.node_id = pose.pose_name
		node.display_name = String(spec[0]).capitalize()
		node.pose = pose
		node.marker_type = spec[2]
		node.meaning = spec[3]
		if not graph.nodes.is_empty():
			graph.nodes[-1].next_nodes = PackedStringArray([String(node.node_id)])
		graph.add_node(node)
	return graph
