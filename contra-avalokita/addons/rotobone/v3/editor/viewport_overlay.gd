@tool
class_name RotoBoneViewportOverlay
extends Node2D

@export var reference_texture: Texture2D:
	set(value):
		reference_texture = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var opacity := 0.42:
	set(value):
		opacity = value
		queue_redraw()
@export_range(1, 128, 1) var hframes := 1:
	set(value):
		hframes = maxi(1, value)
		queue_redraw()
@export_range(1, 128, 1) var vframes := 1:
	set(value):
		vframes = maxi(1, value)
		queue_redraw()
@export_range(0, 16383, 1) var frame := 0:
	set(value):
		frame = maxi(0, value)
		queue_redraw()
@export var onion_skin := true:
	set(value):
		onion_skin = value
		queue_redraw()
@export var anchor_path := NodePath("../RotoBoneAnchor"):
	set(value):
		anchor_path = value
		queue_redraw()
@export var pivot_px := Vector2(24, 48):
	set(value):
		pivot_px = value
		queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var anchor := get_node_or_null(anchor_path) as Marker2D
	if anchor == null:
		return
	var origin := to_local(anchor.global_position)
	if reference_texture == null:
		draw_rect(Rect2(origin - Vector2(24, 48), Vector2(48, 48)), Color(0.32, 0.68, 1.0, opacity * 0.15), true)
		draw_rect(Rect2(origin - Vector2(24, 48), Vector2(48, 48)), Color(0.55, 0.78, 1.0, opacity), false, 1.0)
		return
	if onion_skin:
		_draw_frame(origin, frame - 1, opacity * 0.18)
		_draw_frame(origin, frame + 1, opacity * 0.12)
	_draw_frame(origin, frame, opacity)
	draw_line(origin + Vector2(-7, 0), origin + Vector2(9, 0), Color(0.95, 0.35, 0.3, 0.85), 1.0)
	draw_line(origin + Vector2(0, -7), origin + Vector2(0, 9), Color(0.35, 0.85, 0.5, 0.85), 1.0)


func _draw_frame(origin: Vector2, requested_frame: int, alpha: float) -> void:
	var total := hframes * vframes
	if requested_frame < 0 or requested_frame >= total:
		return
	var cell := Vector2(reference_texture.get_width() / hframes, reference_texture.get_height() / vframes)
	var column := requested_frame % hframes
	var row := requested_frame / hframes
	var source := Rect2(Vector2(column, row) * cell, cell)
	var destination := Rect2(origin - pivot_px, cell)
	draw_texture_rect_region(reference_texture, destination, source, Color(1, 1, 1, clampf(alpha, 0.0, 1.0)))
