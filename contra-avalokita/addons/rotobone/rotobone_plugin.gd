@tool
extends EditorPlugin

const PanelScript := preload("res://addons/rotobone/rotobone_panel.gd")
const RigBuilder := preload("res://addons/rotobone/standard_rig_builder.gd")

const ANCHOR_NAME := "RotoBoneAnchor"
const ANCHOR_META := "rotobone_anchor"

var _dock: EditorDock
var _panel: RotoBonePanel
var _scroll: ScrollContainer
var _position_anchor: Marker2D
var _animation_players: Array[AnimationPlayer] = []
var _active_player: AnimationPlayer
var _last_player_position := -1.0
var _last_anchor_transform := Transform2D.IDENTITY


func _enter_tree() -> void:
	_panel = PanelScript.new()
	_panel.state_changed.connect(_on_panel_state_changed)
	_panel.request_refresh_players.connect(_refresh_animation_players)
	_panel.player_index_changed.connect(_on_player_index_changed)
	_panel.request_create_anchor.connect(_create_or_select_anchor)
	_panel.request_select_anchor.connect(_select_anchor)
	_panel.request_create_standard_rig.connect(_create_standard_rig)

	_dock = EditorDock.new()
	_dock.title = "RotoBone"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	_dock.custom_minimum_size = Vector2(212, 0)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_panel)
	_dock.add_child(_scroll)
	add_dock(_dock)

	var selection := EditorInterface.get_selection()
	if not selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.connect(_on_selection_changed)

	set_process(true)
	_restore_anchor_from_scene()
	_on_selection_changed()
	_refresh_animation_players()
	update_overlays()


func _exit_tree() -> void:
	set_process(false)
	var selection := EditorInterface.get_selection()
	if selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.disconnect(_on_selection_changed)
	if _dock != null:
		remove_dock(_dock)
		_dock.queue_free()
	_dock = null
	_scroll = null
	_panel = null
	_position_anchor = null
	_animation_players.clear()
	_active_player = null


func _handles(object: Object) -> bool:
	return object is Node2D


func _process(_delta: float) -> void:
	if _panel == null:
		return

	if _has_valid_position_anchor():
		if _position_anchor.global_transform != _last_anchor_transform:
			_last_anchor_transform = _position_anchor.global_transform
			update_overlays()
	elif is_instance_valid(_position_anchor):
		_restore_anchor_from_scene()

	if not _panel.sync_enabled:
		return
	if not is_instance_valid(_active_player):
		return
	var position := _active_player.current_animation_position
	if is_equal_approx(position, _last_player_position):
		return
	_last_player_position = position
	var synced_frame := _panel.frame_at_time(position)
	if synced_frame != _panel.frame_index:
		_panel.set_frame_index_from_sync(synced_frame)
		update_overlays()
	_panel.set_current_animation_text(String(_active_player.assigned_animation))


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if _panel == null or _panel.reference_texture == null:
		return
	if not _has_valid_position_anchor():
		return
	if _panel.frame_size.x <= 0 or _panel.frame_size.y <= 0:
		return

	var editor_viewport := EditorInterface.get_editor_viewport_2d()
	if editor_viewport == null:
		return
	var world_to_viewport: Transform2D = editor_viewport.global_canvas_transform
	var anchor_transform: Transform2D = _position_anchor.global_transform

	var local_transform := Transform2D.IDENTITY
	var x_sign := -1.0 if _panel.flip_h else 1.0
	local_transform.x = Vector2(_panel.reference_scale * x_sign, 0.0)
	local_transform.y = Vector2(0.0, _panel.reference_scale)

	overlay.draw_set_transform_matrix(world_to_viewport * anchor_transform * local_transform)

	if _panel.onion_skin and _panel.frame_count > 1:
		_draw_reference_frame(overlay, _panel.frame_index - 1, _panel.opacity * 0.22)
		_draw_reference_frame(overlay, _panel.frame_index + 1, _panel.opacity * 0.16)
	_draw_reference_frame(overlay, _panel.frame_index, _panel.opacity)

	if _panel.show_bounds:
		var top_left := -_panel.anchor_px
		var rect := Rect2(top_left, Vector2(_panel.frame_size))
		overlay.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.30), false, 1.0)

	# The Marker2D itself supplies the persistent editor cross. These short axes
	# remain tied to the exact reference pivot and make X/Y orientation explicit.
	overlay.draw_line(Vector2(-6, 0), Vector2(10, 0), Color(0.95, 0.36, 0.30, 0.92), 1.0)
	overlay.draw_line(Vector2(0, -6), Vector2(0, 10), Color(0.35, 0.82, 0.48, 0.92), 1.0)
	overlay.draw_circle(Vector2.ZERO, 1.8, Color(1.0, 1.0, 1.0, 0.95))

	overlay.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_reference_frame(overlay: Control, requested_index: int, alpha: float) -> void:
	var index := requested_index
	if _panel.loop:
		index = posmod(index, _panel.frame_count)
	else:
		if index < 0 or index >= _panel.frame_count:
			return
	var src_rect := _panel.source_rect(index)
	if src_rect.size.x <= 0 or src_rect.size.y <= 0:
		return
	var destination := Rect2(-_panel.anchor_px, Vector2(_panel.frame_size))
	overlay.draw_texture_rect_region(
		_panel.reference_texture,
		destination,
		src_rect,
		Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	)


func _on_panel_state_changed() -> void:
	update_overlays()


func _on_selection_changed() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if not selected.is_empty():
		var candidate := selected[0]
		if candidate is Marker2D and _is_rotobone_anchor(candidate):
			_set_position_anchor(candidate as Marker2D)
	if not _has_valid_position_anchor():
		_restore_anchor_from_scene()
	_refresh_animation_players()
	update_overlays()


func _is_rotobone_anchor(node: Node) -> bool:
	if node == null:
		return false
	return node.name == ANCHOR_NAME or bool(node.get_meta(ANCHOR_META, false))


func _has_valid_position_anchor() -> bool:
	if not is_instance_valid(_position_anchor):
		return false
	if not _position_anchor.is_inside_tree():
		return false
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return false
	var cursor: Node = _position_anchor
	while cursor != null:
		if cursor == root:
			return true
		cursor = cursor.get_parent()
	return false


func _restore_anchor_from_scene() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_set_position_anchor(null)
		return
	var found := _find_anchor_recursive(root)
	_set_position_anchor(found)


func _find_anchor_recursive(node: Node) -> Marker2D:
	if node is Marker2D and _is_rotobone_anchor(node):
		return node as Marker2D
	for child in node.get_children():
		var found := _find_anchor_recursive(child)
		if found != null:
			return found
	return null


func _set_position_anchor(anchor: Marker2D) -> void:
	_position_anchor = anchor
	if is_instance_valid(_position_anchor):
		_last_anchor_transform = _position_anchor.global_transform
		if _panel != null:
			_panel.set_anchor_node_name(String(_position_anchor.get_path()))
	else:
		_last_anchor_transform = Transform2D.IDENTITY
		if _panel != null:
			_panel.set_anchor_node_name("<create Pos node>")


func _create_or_select_anchor() -> void:
	if _has_valid_position_anchor():
		_select_anchor()
		return
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return

	var marker := Marker2D.new()
	marker.name = ANCHOR_NAME
	marker.gizmo_extents = 13.0
	marker.set_meta(ANCHOR_META, true)
	marker.set_meta("rotobone_role", "reference_xy_origin")
	marker.position = _global_to_scene_root_local(_suggest_spawn_global_position(), scene_root)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Create RotoBone Position Anchor", 0, scene_root)
	undo_redo.add_do_method(scene_root, &"add_child", marker, true)
	undo_redo.add_do_method(marker, &"set_owner", scene_root)
	undo_redo.add_do_reference(marker)
	undo_redo.add_undo_method(scene_root, &"remove_child", marker)
	undo_redo.commit_action()

	_set_position_anchor(marker)
	_select_node(marker)
	update_overlays()


func _select_anchor() -> void:
	if not _has_valid_position_anchor():
		_restore_anchor_from_scene()
	if _has_valid_position_anchor():
		_select_node(_position_anchor)


func _create_standard_rig() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return
	if not _has_valid_position_anchor():
		_create_or_select_anchor()

	var rig: Node2D = RigBuilder.create_standard_biped()
	var spawn_global := _suggest_spawn_global_position()
	if _has_valid_position_anchor():
		# The generated rig is pelvis-centered. Estimate the template hip at about
		# 52% of frame height, then place that point under the reference image.
		# This works for both feet-anchored locomotion and the shown climb-back
		# contact anchor without making the rig depend on one animation.
		var hip_px := Vector2(float(_panel.frame_size.x) * 0.5, float(_panel.frame_size.y) * 0.52)
		var local_delta := hip_px - _panel.anchor_px
		if _panel.flip_h:
			local_delta.x *= -1.0
		local_delta *= _panel.reference_scale
		spawn_global = _position_anchor.global_transform * local_delta
	rig.position = _global_to_scene_root_local(spawn_global, scene_root)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Create RotoBone Standard Rig", 0, scene_root)
	undo_redo.add_do_method(scene_root, &"add_child", rig, true)
	undo_redo.add_do_method(self, &"_set_owner_recursive", rig, scene_root)
	undo_redo.add_do_reference(rig)
	undo_redo.add_undo_method(scene_root, &"remove_child", rig)
	undo_redo.commit_action()

	var skeleton := rig.get_node_or_null("Skeleton2D") as Skeleton2D
	if skeleton != null:
		_select_node(skeleton)
	else:
		_select_node(rig)
	_refresh_animation_players()
	update_overlays()


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	if node == null:
		return
	node.owner = owner_node
	for child in node.get_children():
		_set_owner_recursive(child, owner_node)


func _suggest_spawn_global_position() -> Vector2:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if not selected.is_empty() and selected[0] is Node2D:
		return (selected[0] as Node2D).global_position
	if _has_valid_position_anchor():
		return _position_anchor.global_position
	return Vector2.ZERO


func _global_to_scene_root_local(global_position: Vector2, scene_root: Node) -> Vector2:
	if scene_root is Node2D:
		return (scene_root as Node2D).to_local(global_position)
	return global_position


func _select_node(node: Node) -> void:
	if node == null:
		return
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(node)


func _refresh_animation_players() -> void:
	_animation_players.clear()
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		if _panel != null:
			_panel.set_animation_players(PackedStringArray())
		return
	_collect_animation_players(scene_root)
	var names := PackedStringArray()
	var preferred_index := 0
	for i in range(_animation_players.size()):
		var player := _animation_players[i]
		names.append(String(player.get_path()))
		if _selection_is_related_to_player(player):
			preferred_index = i
	if _panel != null:
		_panel.set_animation_players(names, preferred_index)
	_on_player_index_changed(preferred_index)


func _collect_animation_players(node: Node) -> void:
	if node is AnimationPlayer:
		_animation_players.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect_animation_players(child)


func _selection_is_related_to_player(player: AnimationPlayer) -> bool:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty():
		return false
	var cursor: Node = selected[0]
	while cursor != null:
		if cursor == player.get_parent():
			return true
		cursor = cursor.get_parent()
	return false


func _on_player_index_changed(index: int) -> void:
	if index < 0 or index >= _animation_players.size():
		_active_player = null
		if _panel != null:
			_panel.set_current_animation_text("")
		return
	_active_player = _animation_players[index]
	_last_player_position = -1.0
	if _panel != null:
		_panel.set_current_animation_text(String(_active_player.assigned_animation))
	update_overlays()
