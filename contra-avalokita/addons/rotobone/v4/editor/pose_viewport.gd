@tool
class_name RotoPoseViewport
extends Node2D

signal target_changed(target_name: StringName, position: Vector2)

@export var pose: RotoPose:
	set(value):
		pose = value
		_rebuild_gizmos()
@export_node_path("Skeleton2D") var skeleton_path: NodePath
@export var enabled_targets := PackedStringArray(["head", "hand_r", "hand_l", "foot_r", "foot_l", "weapon_tip", "body"])
@export var reference_texture: Texture2D:
	set(value):
		reference_texture = value
		queue_redraw()
@export var reference_hframes := 1:
	set(value):
		reference_hframes = maxi(value, 1)
		queue_redraw()
@export var reference_vframes := 1:
	set(value):
		reference_vframes = maxi(value, 1)
		queue_redraw()
@export var reference_frame := 0:
	set(value):
		reference_frame = maxi(value, 0)
		queue_redraw()
@export var reference_pivot := Vector2(24, 48):
	set(value):
		reference_pivot = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var reference_opacity := 0.55:
	set(value):
		reference_opacity = clampf(value, 0.0, 1.0)
		queue_redraw()

var _active: RotoTargetGizmo


func _ready() -> void:
	_rebuild_gizmos()
	queue_redraw()


func _draw() -> void:
	if reference_texture == null:
		return
	var columns := maxi(reference_hframes, 1)
	var rows := maxi(reference_vframes, 1)
	var cell := Vector2(reference_texture.get_width() / columns, reference_texture.get_height() / rows)
	var frame_count := columns * rows
	var frame := posmod(reference_frame, frame_count)
	var source := Rect2(Vector2(frame % columns, frame / columns) * cell, cell)
	draw_texture_rect_region(reference_texture, Rect2(-reference_pivot, cell), source, Color(1, 1, 1, reference_opacity))


func set_reference_frame(frame: int) -> void:
	reference_frame = frame


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin_target_drag(to_local(get_global_mouse_position()))
		else:
			end_target_drag()
	elif event is InputEventMouseMotion and _active != null:
		drag_active_target(to_local(get_global_mouse_position()))
		get_viewport().set_input_as_handled()


func begin_target_drag(local_position: Vector2) -> bool:
	_active = _gizmo_at(local_position)
	return _active != null


func drag_active_target(local_position: Vector2) -> bool:
	if _active == null:
		return false
	_active.position = local_position
	_on_target_moved(_active.target_name, local_position)
	return true


func end_target_drag() -> void:
	_active = null


func _rebuild_gizmos() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child is RotoTargetGizmo:
			child.queue_free()
	if pose == null:
		return
	for target_name in enabled_targets:
		if not pose.has_target(StringName(target_name)):
			continue
		var gizmo := RotoTargetGizmo.new()
		gizmo.target_name = StringName(target_name)
		gizmo.position = pose.get_target(StringName(target_name))
		gizmo.target_moved.connect(_on_target_moved)
		add_child(gizmo)


func _gizmo_at(local_position: Vector2) -> RotoTargetGizmo:
	for child in get_children():
		if child is RotoTargetGizmo and child.position.distance_to(local_position) <= child.radius + 5.0:
			return child
	return null


func _on_target_moved(target_name: StringName, position: Vector2) -> void:
	pose.set_target(target_name, position)
	target_changed.emit(target_name, position)
