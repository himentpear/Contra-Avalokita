@tool
class_name RotoPoseController
extends Node

@export_node_path("Skeleton2D") var skeleton_path: NodePath
@export var semantic_map: Dictionary = {}
@export var current_pose: RotoPose:
	set(value):
		current_pose = value
		_apply_current_pose()

var _bridge := RotoIKBridge.new()


func _ready() -> void:
	_bind()
	_apply_current_pose()


func configure(skeleton: Skeleton2D, mapping: Dictionary) -> void:
	skeleton_path = get_path_to(skeleton)
	semantic_map = mapping.duplicate(true)
	_bridge.bind(skeleton, semantic_map)
	_apply_current_pose()


func _bind() -> void:
	var skeleton := get_node_or_null(skeleton_path) as Skeleton2D
	if skeleton != null:
		_bridge.bind(skeleton, semantic_map)


func _apply_current_pose() -> void:
	if not is_inside_tree() or current_pose == null:
		return
	if _bridge.solver.skeleton == null:
		_bind()
	_bridge.solve(current_pose)
