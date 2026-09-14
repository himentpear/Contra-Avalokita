@tool
extends EditorPlugin

const Workspace := preload("res://addons/rotobone/v3/core/rotobone_workspace.gd")
const Dock := preload("res://addons/rotobone/v3/editor/rotobone_v3_dock.gd")
const Marker := preload("res://addons/rotobone/v3/animation/keyframe_marker.gd")
const Baker := preload("res://addons/rotobone/v3/animation/pose_baker.gd")
const Overlay := preload("res://addons/rotobone/v3/editor/viewport_overlay.gd")

var _workspace := Workspace.new()
var _dock_host: EditorDock
var _dock: RotoBoneV3Dock


func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.animation_selected.connect(_on_animation_selected)
	_dock.asset_action_selected.connect(_on_asset_action_selected)
	_dock.time_requested.connect(_workspace.set_time)
	_dock.marker_requested.connect(_on_marker_requested)
	_dock.bake_requested.connect(_on_bake_requested)
	_dock.overlay_settings_changed.connect(_on_overlay_settings_changed)
	_workspace.template_status_changed.connect(_dock.set_template_status)
	_workspace.profile_changed.connect(_dock.set_profile)
	_workspace.time_changed.connect(_dock.set_time)
	_workspace.asset_action_changed.connect(_on_asset_action_changed)

	_dock_host = EditorDock.new()
	_dock_host.title = "RotoBone v3"
	_dock_host.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	_dock_host.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	_dock_host.custom_minimum_size = Vector2(220, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_dock)
	_dock_host.add_child(scroll)
	add_dock(_dock_host)

	if not scene_changed.is_connected(_on_scene_changed):
		scene_changed.connect(_on_scene_changed)
	call_deferred("_refresh_workspace")


func _exit_tree() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if _dock_host != null:
		remove_dock(_dock_host)
		_dock_host.queue_free()
	_dock_host = null
	_dock = null
	_workspace.adapter.clear()


func _on_scene_changed(_scene_root: Node) -> void:
	_refresh_workspace()


func _refresh_workspace() -> void:
	if _dock == null:
		return
	_workspace.initialize(EditorInterface.get_edited_scene_root())
	_dock.set_profiles(_workspace.profiles)
	_dock.set_asset_actions(_workspace.asset_actions)
	if _workspace.active_profile != null:
		_dock.set_profile(_workspace.active_profile)
		_dock.set_time(_workspace.current_time)


func _on_animation_selected(index: int) -> void:
	_workspace.select_profile(index)
	if _workspace.active_profile != null:
		var asset_index := _workspace.asset_action_index_for_profile(_workspace.active_profile.animation_name)
		if asset_index >= 0:
			_dock.select_asset_action(asset_index)
			_workspace.select_asset_action(asset_index)


func _on_asset_action_selected(index: int) -> void:
	_workspace.select_asset_action(index)
	_dock.select_asset_action(index)


func _on_asset_action_changed(action: Dictionary) -> void:
	_dock.set_asset_action(action)
	var output_player := _find_output_player()
	if output_player != null:
		var placeholder := _workspace.placeholder_animation_name(action)
		if output_player.has_animation(placeholder):
			output_player.assigned_animation = placeholder
			output_player.seek(0.0, true)
			output_player.pause()
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var overlay := _find_overlay(root)
	if overlay == null:
		return
	var texture_path := String(action.get("reference_sprite", ""))
	var texture := load(texture_path) as Texture2D if not texture_path.is_empty() else null
	overlay.reference_texture = texture
	var frame_width := maxi(1, int(action.get("frame_width", 48)))
	var frame_height := maxi(1, int(action.get("frame_height", 48)))
	if texture != null:
		overlay.hframes = maxi(1, texture.get_width() / frame_width)
		overlay.vframes = maxi(1, texture.get_height() / frame_height)
	overlay.pivot_px = Vector2(
		float(action.get("pivot_x", frame_width * 0.5)),
		float(action.get("pivot_y", frame_height))
	)
	overlay.frame = 0


func _on_marker_requested(type: int) -> void:
	var marker := Marker.new()
	marker.type = clampi(type, Marker.MarkerType.CONTACT, Marker.MarkerType.IMPACT) as Marker.MarkerType
	var targets := PackedStringArray()
	for selected in EditorInterface.get_selection().get_selected_nodes():
		if selected is Bone2D:
			targets.append(String(selected.name))
	marker.bone_targets = targets
	_workspace.add_marker(marker)


func _on_bake_requested() -> void:
	if _workspace.adapter.skeleton == null or _workspace.active_profile == null:
		_dock.set_template_status(false, "Mud Character · template not detected")
		return
	var output_player := _find_output_player()
	if output_player == null:
		_dock.set_template_status(false, "Add a wrapper AnimationPlayer; source clips stay read-only")
		return
	var inserted := Baker.new().bake_pose(
		output_player,
		_workspace.adapter.skeleton,
		_workspace.active_profile.animation_name,
		_workspace.current_time
	)
	if inserted > 0:
		EditorInterface.mark_scene_as_unsaved()
		_dock.set_template_status(true, "Mud Character · baked %d rotation keys" % inserted)


func _find_output_player() -> AnimationPlayer:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root == _workspace.adapter.instance:
		return null
	for child in root.get_children():
		if child is AnimationPlayer and child != _workspace.adapter.animation_player:
			return child as AnimationPlayer
	return null


func _on_overlay_settings_changed(opacity: float, frame: int, onion_skin: bool) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var overlay := _find_overlay(root)
	if overlay == null:
		return
	overlay.opacity = opacity
	overlay.frame = frame
	overlay.onion_skin = onion_skin
	EditorInterface.mark_scene_as_unsaved()


func _find_overlay(node: Node) -> RotoBoneViewportOverlay:
	if node is RotoBoneViewportOverlay:
		return node as RotoBoneViewportOverlay
	for child in node.get_children():
		var found := _find_overlay(child)
		if found != null:
			return found
	return null
