class_name MudEyeController
extends Node2D
@export var blink_interval := 4.2
@export var blink_duration := 0.13
@export var eye_color := Color("eff6bc")
@export var pupil_color := Color("172729")
var clock := 0.0
var look := 0.0
var hurt_amount := 0.0
var dead := false

func sync(rig: MudRig, delta: float, look_direction: float) -> void:
	position = rig.point(&"Head")
	clock += delta
	look = lerpf(look, clampf(look_direction, -1, 1), 1.0 - exp(-delta * 12))
	queue_redraw()

func _draw() -> void:
	var closed := dead or fmod(clock, blink_interval) < blink_duration
	var h := 1.0 if closed else 3.0 * (1.0 - hurt_amount * 0.5)
	draw_rect(Rect2(0, -3, 2, h), eye_color.darkened(0.18))
	draw_rect(Rect2(4, -3, 4, h + (0 if closed else 1)), eye_color)
	if not closed:
		draw_rect(Rect2(6 + look * 0.6, -2, 1, 2), pupil_color)
		draw_rect(Rect2(1, -2, 1, 1), pupil_color)

