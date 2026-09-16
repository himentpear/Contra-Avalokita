class_name LightingRegistry
extends RefCounted

## Decoupled, presentation-scoped 2D light caching registry.
## Provides fast candidate light querying without walking the full SceneTree.

const LIGHT_GROUP := &"world_lights_2d"

static var _registered_lights: Array[PointLight2D] = []

static func register_light(light: PointLight2D) -> void:
	if not is_instance_valid(light):
		return
	if not _registered_lights.has(light):
		_registered_lights.append(light)
	if not light.is_in_group(LIGHT_GROUP):
		light.add_to_group(LIGHT_GROUP)
	if not light.tree_exiting.is_connected(unregister_light.bind(light)):
		light.tree_exiting.connect(unregister_light.bind(light))

static func unregister_light(light: PointLight2D) -> void:
	_registered_lights.erase(light)

static func clear() -> void:
	_registered_lights.clear()

static func get_candidate_lights(tree: SceneTree, world_pos: Vector2, max_radius: float = 800.0) -> Array[PointLight2D]:
	var result: Array[PointLight2D] = []
	var max_dist_sq := max_radius * max_radius

	# 1. Evaluate explicit registry first
	var i := _registered_lights.size() - 1
	while i >= 0:
		var light := _registered_lights[i]
		if not is_instance_valid(light) or not light.is_inside_tree():
			_registered_lights.remove_at(i)
			i -= 1
			continue
		if light.visible and light.enabled and light.energy > 0.001:
			var d_sq := world_pos.distance_squared_to(light.global_position)
			if d_sq <= max_dist_sq:
				result.append(light)
		i -= 1

	# 2. If registry empty, fallback to tree group once
	if result.is_empty() and is_instance_valid(tree):
		var group_nodes := tree.get_nodes_in_group(LIGHT_GROUP)
		for node in group_nodes:
			var light := node as PointLight2D
			if is_instance_valid(light) and light.visible and light.enabled and light.energy > 0.001:
				if not _registered_lights.has(light):
					register_light(light)
				var d_sq := world_pos.distance_squared_to(light.global_position)
				if d_sq <= max_dist_sq and not result.has(light):
					result.append(light)

	# 3. If still empty, search scene for PointLight2D nodes within radius
	if result.is_empty() and is_instance_valid(tree):
		var root_node := tree.current_scene if is_instance_valid(tree.current_scene) else tree.root
		if is_instance_valid(root_node):
			for node in root_node.find_children("*", "PointLight2D", true, false):
				var light := node as PointLight2D
				if is_instance_valid(light) and light.visible and light.enabled and light.energy > 0.001:
					if not _registered_lights.has(light):
						register_light(light)
					var d_sq := world_pos.distance_squared_to(light.global_position)
					if d_sq <= max_dist_sq and not result.has(light):
						result.append(light)

	return result
