class_name AnimationLayerManager
extends Node

signal layer_registered(layer: AnimationLayer)
signal layer_unregistered(layer: AnimationLayer)

var context := AnimationContext.new()
var _layers: Array[AnimationLayer] = []

func setup(
	character: Node,
	animation_player: AnimationPlayer = null,
	skeleton: Skeleton2D = null
) -> void:
	context.bind(character, animation_player, skeleton)

func register_layer(layer: AnimationLayer) -> bool:
	if layer == null or _layers.has(layer):
		return false
	if layer.get_parent() != null and layer.get_parent() != self:
		push_error("AnimationLayer must be unparented or already owned by this manager")
		return false
	if layer.get_parent() == null:
		add_child(layer)
	_layers.append(layer)
	layer_registered.emit(layer)
	return true

func unregister_layer(layer: AnimationLayer) -> bool:
	if not _layers.has(layer):
		return false
	_layers.erase(layer)
	if layer.get_parent() == self:
		remove_child(layer)
	layer_unregistered.emit(layer)
	return true

func get_layers() -> Array[AnimationLayer]:
	return _layers.duplicate()

func get_active_layers() -> Array[AnimationLayer]:
	var active: Array[AnimationLayer] = []
	for layer in _layers:
		if is_instance_valid(layer) and layer.is_active():
			active.append(layer)
	active.sort_custom(func(a: AnimationLayer, b: AnimationLayer) -> bool:
		return a.priority > b.priority
	)
	return active

func get_dominant_layer() -> AnimationLayer:
	var active := get_active_layers()
	return active[0] if not active.is_empty() else null

func update_layers(delta: float, override_context: AnimationContext = null) -> void:
	var active_context := override_context if override_context != null else context
	if override_context == null:
		active_context.refresh()
	for layer in _layers:
		if is_instance_valid(layer):
			layer.update(delta, active_context)
