@tool
class_name RotoPose
extends Resource

@export var pose_name: StringName = &"pose"
@export var time := 0.0
@export var targets: Dictionary = {}
@export var rotation_hints: Dictionary = {}
@export var body_lean := 0.0
@export var tags := PackedStringArray()


func set_target(target_name: StringName, position: Vector2) -> void:
	targets[String(target_name)] = position
	emit_changed()


func get_target(target_name: StringName, fallback := Vector2.ZERO) -> Vector2:
	var value: Variant = targets.get(String(target_name), fallback)
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback


func has_target(target_name: StringName) -> bool:
	return targets.has(String(target_name))


func to_dictionary() -> Dictionary:
	var encoded_targets := {}
	for target_name in targets:
		var point := get_target(StringName(target_name))
		encoded_targets[target_name] = {"x": point.x, "y": point.y}
	return {
		"name": String(pose_name),
		"time": time,
		"targets": encoded_targets,
		"rotation_hints": rotation_hints.duplicate(true),
		"body_lean": body_lean,
		"tags": Array(tags),
	}
