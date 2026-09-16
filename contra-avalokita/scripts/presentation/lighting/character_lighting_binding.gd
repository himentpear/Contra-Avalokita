class_name CharacterLightingBinding
extends Resource

## Explicitly binds visual renderers and fx anchors to the lighting runtime.
## Prevents reflection/dynamic string lookup in the lighting controller.

@export var body_renderer_paths: Array[NodePath] = []
@export var weapon_renderer_paths: Array[NodePath] = []
@export var weapon_slot_path: NodePath
@export var emissive_renderer_paths: Array[NodePath] = []
@export var local_fx_behind_path: NodePath
@export var local_fx_body_path: NodePath
@export var local_fx_front_path: NodePath
@export var ground_shadow_path: NodePath

var body_renderers: Array[CanvasItem] = []
var weapon_renderers: Array[CanvasItem] = []
var emissive_renderers: Array[CanvasItem] = []
var local_fx_behind: CanvasItem = null
var local_fx_body: CanvasItem = null
var local_fx_front: CanvasItem = null
var ground_shadow: CanvasItem = null
var weapon_slot_node: Node = null

func resolve(root: Node) -> void:
	if not is_instance_valid(root):
		return
	if not body_renderer_paths.is_empty():
		body_renderers.clear()
		for path in body_renderer_paths:
			if not path.is_empty():
				var node := root.get_node_or_null(path) as CanvasItem
				if is_instance_valid(node):
					body_renderers.append(node)
	if not weapon_renderer_paths.is_empty():
		weapon_renderers.clear()
		for path in weapon_renderer_paths:
			if not path.is_empty():
				var node := root.get_node_or_null(path) as CanvasItem
				if is_instance_valid(node):
					weapon_renderers.append(node)
	if not emissive_renderer_paths.is_empty():
		emissive_renderers.clear()
		for path in emissive_renderer_paths:
			if not path.is_empty():
				var node := root.get_node_or_null(path) as CanvasItem
				if is_instance_valid(node):
					emissive_renderers.append(node)
	if not local_fx_behind_path.is_empty():
		local_fx_behind = root.get_node_or_null(local_fx_behind_path) as CanvasItem
	if not local_fx_body_path.is_empty():
		local_fx_body = root.get_node_or_null(local_fx_body_path) as CanvasItem
	if not local_fx_front_path.is_empty():
		local_fx_front = root.get_node_or_null(local_fx_front_path) as CanvasItem
	if not ground_shadow_path.is_empty():
		ground_shadow = root.get_node_or_null(ground_shadow_path) as CanvasItem

	if not weapon_slot_path.is_empty():
		weapon_slot_node = root.get_node_or_null(weapon_slot_path)
		if is_instance_valid(weapon_slot_node):
			if not weapon_slot_node.child_entered_tree.is_connected(_on_weapon_slot_child_entered):
				weapon_slot_node.child_entered_tree.connect(_on_weapon_slot_child_entered)
			if not weapon_slot_node.child_exiting_tree.is_connected(_on_weapon_slot_child_exiting):
				weapon_slot_node.child_exiting_tree.connect(_on_weapon_slot_child_exiting)
			for child in weapon_slot_node.get_children():
				_on_weapon_slot_child_entered(child)

func _on_weapon_slot_child_entered(node: Node) -> void:
	if node is CanvasItem and not weapon_renderers.has(node):
		weapon_renderers.append(node as CanvasItem)
	for child in node.find_children("*", "CanvasItem", true, false):
		var item := child as CanvasItem
		if is_instance_valid(item) and not weapon_renderers.has(item):
			weapon_renderers.append(item)

func _on_weapon_slot_child_exiting(node: Node) -> void:
	if node in weapon_renderers:
		weapon_renderers.erase(node)
	for child in node.find_children("*", "CanvasItem", true, false):
		if child in weapon_renderers:
			weapon_renderers.erase(child)

func bind_body(renderer: CanvasItem) -> CharacterLightingBinding:
	if is_instance_valid(renderer) and not body_renderers.has(renderer):
		body_renderers.append(renderer)
	return self

func bind_weapon(renderer: CanvasItem) -> CharacterLightingBinding:
	if is_instance_valid(renderer) and not weapon_renderers.has(renderer):
		weapon_renderers.append(renderer)
	return self

func unbind_weapon(renderer: CanvasItem) -> CharacterLightingBinding:
	if renderer in weapon_renderers:
		weapon_renderers.erase(renderer)
	return self

func clear_weapons() -> CharacterLightingBinding:
	weapon_renderers.clear()
	return self

func bind_emissive(renderer: CanvasItem) -> CharacterLightingBinding:
	if is_instance_valid(renderer) and not emissive_renderers.has(renderer):
		emissive_renderers.append(renderer)
	return self

func bind_ground_shadow(shadow: CanvasItem) -> CharacterLightingBinding:
	ground_shadow = shadow
	return self
