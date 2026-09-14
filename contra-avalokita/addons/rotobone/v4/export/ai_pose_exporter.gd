@tool
class_name RotoAIPoseExporter
extends RefCounted


func graph_to_dictionary(graph: RotoPoseGraph) -> Dictionary:
	var phases: Array[Dictionary] = []
	var target_names := {}
	for node in graph.sorted_nodes():
		if node.pose == null:
			continue
		phases.append({
			"name": String(node.node_id),
			"time": node.pose.time,
			"meaning": node.meaning,
			"marker": node.marker_symbol(),
			"tags": Array(node.pose.tags),
			"targets": node.pose.to_dictionary()["targets"],
		})
		for target_name in node.pose.targets:
			target_names[target_name] = _target_meaning(String(target_name))
	return {
		"format": "rotodata",
		"version": 1,
		"animation": String(graph.graph_name),
		"intent": graph.intent,
		"phases": phases,
		"targets": target_names,
	}


func export_graph(graph: RotoPoseGraph, path: String) -> Error:
	return RotoPoseJSONWriter.new().write_json(path, graph_to_dictionary(graph))


func _target_meaning(target_name: String) -> String:
	if target_name == "weapon_tip":
		return "blade"
	return target_name.trim_suffix("_r").trim_suffix("_l")
