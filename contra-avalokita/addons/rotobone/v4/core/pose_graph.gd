@tool
class_name RotoPoseGraph
extends Resource

@export var graph_name: StringName = &"animation"
@export var intent := ""
@export var entry_node: StringName = &""
@export var nodes: Array[RotoPoseNode] = []


func add_node(node: RotoPoseNode) -> void:
	if node == null or get_node_by_id(node.node_id) != null:
		return
	nodes.append(node)
	if entry_node.is_empty():
		entry_node = node.node_id
	emit_changed()


func get_node_by_id(node_id: StringName) -> RotoPoseNode:
	for node in nodes:
		if node != null and node.node_id == node_id:
			return node
	return null


func sorted_nodes() -> Array[RotoPoseNode]:
	var result := nodes.duplicate()
	result.sort_custom(func(a: RotoPoseNode, b: RotoPoseNode) -> bool:
		return a.pose != null and b.pose != null and a.pose.time < b.pose.time
	)
	return result
