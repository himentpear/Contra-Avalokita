@tool
class_name RotoAnimationRuntime
extends Node

@export var graph: RotoPoseGraph
@export_node_path("RotoPoseController") var controller_path: NodePath
@export var current_node: StringName:
	set(value):
		current_node = value
		_apply_node(value)


func _apply_node(node_id: StringName) -> void:
	if graph == null or not is_inside_tree():
		return
	var node := graph.get_node_by_id(node_id)
	var controller := get_node_or_null(controller_path) as RotoPoseController
	if node != null and controller != null:
		controller.current_pose = node.pose
