@tool
class_name RotoSemanticTarget
extends Resource

@export var target_name: StringName = &""
@export var position := Vector2.ZERO
@export var direction := Vector2.RIGHT
@export var enabled := true
@export var weight := 1.0
@export var metadata: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"x": position.x,
		"y": position.y,
		"direction_x": direction.x,
		"direction_y": direction.y,
		"enabled": enabled,
		"weight": weight,
	}
