@tool
extends EditorPlugin

const PanelScript := preload("res://addons/rotobone/rotobone_panel.gd")

var _dock: EditorDock
var _panel: RotoBonePanel
var _scroll: ScrollContainer
var _anchor_node: Node2D
var _animation_players: Array[AnimationPlayer] = []
var _active_player: AnimationPlayer
var _last_player_position := -1.0


func _enter_tree() -> void:
	_panel = PanelScript.new()
	_panel.state_changed.connect(_on_panel_state_changed)
	_panel.request_refresh_players.connect(_refresh_animation_players)
	_panel.player_index_changed.connect(_on_player_index_changed)

	_dock = EditorDock.new()
	_dock.title = "RotoBone"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_panel)
	_dock.add_child(_scroll)
	add_dock(_dock)

	var selection := EditorInterface.get_selection()
	if not selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.connect(_on_selection_changed)
	set_process(true)
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
	_anchor_node = null
	_animation_players.clear()
	_active_player = null


func _handles(object: Object) -> bool:
	return object is Node2D


func _process(_delta: float) -> void:
	if _panel == null:
		return
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
	if not is_instance_valid(_anchor_node):
		return
	if _panel.frame_size.x <= 0 or _panel.frame_size.y <= 0:
		return

	var editor_viewport := EditorInterface.get_editor_viewport_2d()
	if editor_viewport == null:
		return
	var world_to_viewport: Transform2D = editor_viewport.global_canvas_transform
	var anchor_transform: Transform2D = _anchor_node.global_transform

	var local_transform := Transform2D.IDENTITY
	var x_sign := -1.0 if _panel.flip_h else 1.0
	local_transform.x = Vector2(_panel.reference_scale * x_sign, 0.0)
	local_transform.y = Vector2(0.0, _panel.reference_scale)
	local_transform.origin = _panel.offset_px

	overlay.draw_set_transform_matrix(world_to_viewport * anchor_transform * local_transform)

	if _panel.onion_skin and _panel.frame_count > 1:
		_draw_reference_frame(overlay, _panel.frame_index - 1, _panel.opacity * 0.22)
		_draw_reference_frame(overlay, _panel.frame_index + 1, _panel.opacity * 0.16)
	_draw_reference_frame(overlay, _panel.frame_index, _panel.opacity)

	if _panel.show_bounds:
		var top_left := -_panel.anchor_px
		var rect := Rect2(top_left, Vector2(_panel.frame_size))
		overlay.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.32), false, 1.0)
		overlay.draw_line(Vector2(-4, 0), Vector2(4, 0), Color(1.0, 1.0, 1.0, 0.7), 1.0)
		overlay.draw_line(Vector2(0, -4), Vector2(0, 4), Color(1.0, 1.0, 1.0, 0.7), 1.0)

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
	var new_anchor: Node2D = null
	if not selected.is_empty():
		var candidate := selected[0]
		if candidate is Bone2D:
			new_anchor = _find_skeleton_ancestor(candidate)
		elif candidate is Skeleton2D:
			new_anchor = candidate
		elif candidate is Node2D:
			new_anchor = candidate
	_anchor_node = new_anchor
	if _panel != null:
		if is_instance_valid(_anchor_node):
			_panel.set_anchor_node_name(String(_anchor_node.get_path()))
		else:
			_panel.set_anchor_node_name("<select Skeleton2D or Bone2D>")
	_refresh_animation_players()
	update_overlays()


func _find_skeleton_ancestor(node: Node) -> Skeleton2D:
	var cursor: Node = node
	while cursor != null:
		if cursor is Skeleton2D:
			return cursor as Skeleton2D
		cursor = cursor.get_parent()
	return null


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
		if is_instance_valid(_anchor_node) and _is_related_to_anchor(player, _anchor_node):
			preferred_index = i
	_panel.set_animation_players(names, preferred_index)
	_on_player_index_changed(preferred_index)


func _collect_animation_players(node: Node) -> void:
	if node is AnimationPlayer:
		_animation_players.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect_animation_players(child)


func _is_related_to_anchor(player: AnimationPlayer, anchor: Node2D) -> bool:
	var cursor: Node = anchor
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
