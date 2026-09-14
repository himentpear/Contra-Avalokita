class_name CombatImpactFX
extends Node2D

@export var duration := 0.22
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var p := clampf(elapsed / duration, 0.0, 1.0)
	var radius := lerpf(4.0, 24.0, p)
	var alpha := 1.0 - p
	var ring_col := Color(1.0, 0.9, 0.6, alpha * 0.8)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, ring_col, 1.5)
	
	# Sparks
	for i in range(6):
		var angle := i * (TAU / 6.0) + (p * 0.5)
		var spark_dist := lerpf(6.0, 32.0, p)
		var s_pos := Vector2(cos(angle), sin(angle)) * spark_dist
		draw_circle(s_pos, maxf(1.0, 2.5 * (1.0 - p)), Color(1.0, 0.95, 0.8, alpha))
