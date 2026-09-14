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

var _active: RotoTargetGizmo


func _ready() -> void:
	_rebuild_gizmos()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_active = _gizmo_at(get_global_mouse_position())
		else:
			_active = null
	elif event is InputEventMouseMotion and _active != null:
		_active.drag_to(get_global_mouse_position())
		get_viewport().set_input_as_handled()


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


func _gizmo_at(point: Vector2) -> RotoTargetGizmo:
	for child in get_children():
		if child is RotoTargetGizmo and child.hit_test(point):
			return child
	return null


func _on_target_moved(target_name: StringName, position: Vector2) -> void:
	pose.set_target(target_name, position)
	target_changed.emit(target_name, position)
