@tool
class_name RotoTargetGizmo
extends Node2D

signal target_moved(target_name: StringName, position: Vector2)

@export var target_name: StringName = &"hand_r"
@export var color := Color(0.2, 0.9, 0.75)
@export var radius := 7.0
var dragging := false


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(color, 0.18))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color, 2.0)
	draw_line(Vector2(-radius - 3.0, 0), Vector2(radius + 3.0, 0), color, 1.0)
	draw_line(Vector2(0, -radius - 3.0), Vector2(0, radius + 3.0), color, 1.0)


func hit_test(point: Vector2) -> bool:
	return global_position.distance_to(point) <= radius + 5.0


func drag_to(point: Vector2) -> void:
	global_position = point
	target_moved.emit(target_name, position)
