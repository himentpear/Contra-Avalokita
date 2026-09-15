@abstract
class_name AnimationLayer
extends Node

signal animation_changed(previous: StringName, current: StringName)

var weight: float = 1.0:
	set(value):
		weight = clampf(value, 0.0, 1.0)
var priority: int = 0
var current_animation: StringName = &""

func play(animation: StringName) -> void:
	if current_animation == animation:
		return
	var previous := current_animation
	current_animation = animation
	animation_changed.emit(previous, current_animation)

func stop() -> void:
	play(&"")

func is_active() -> bool:
	return weight > 0.0 and current_animation != &""

func update(_delta: float, _context: AnimationContext) -> void:
	pass
