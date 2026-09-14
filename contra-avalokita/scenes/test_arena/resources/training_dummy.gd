extends Node2D
const HitDataType = preload("res://scripts/combat/hit_data.gd")
var hit_count := 0
var flash := 0.0

var react_offset := Vector2.ZERO
var react_tilt := 0.0
var local_time_scale := 1.0
var react_time := 0.0
var react_duration := 0.0
var react_type := ""

func _ready() -> void:
	var area := Area2D.new()
	area.name = "Hurtbox"
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("owner_character", self)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 260)
	collider.shape = shape
	collider.position.y = 50
	area.add_child(collider)
	add_child(area)

func receive_hit(hit_data: Variant) -> void:
	var damage: float = hit_data.damage if (hit_data is Object and "damage" in hit_data) else float(hit_data)
	hit_count += 1
	preload("res://scripts/realm_hit_feedback.gd").emit_hit(self,damage,Vector2(0,-63))
	flash = maxf(flash, 0.12)
	if damage <= 7.5:
		react_type = "jab"
		react_duration = 0.14
		react_time = react_duration
		react_offset = Vector2(2.5, -0.2)
		react_tilt = 0.04
	elif damage <= 9.5:
		react_type = "cross"
		react_duration = 0.22
		react_time = react_duration
		react_offset = Vector2(4.5, -0.5)
		react_tilt = 0.06
	else:
		react_type = "hook"
		react_duration = 0.25
		react_time = react_duration
		react_offset = Vector2(3.0, 0.0)
		react_tilt = -0.12
	if hit_data is HitDataType:
		hit_data.victim = self
		var manager := get_node_or_null("/root/HitstopManager")
		if manager:
			manager.request_hitstop(hit_data)

func _process(delta: float) -> void:
	if local_time_scale <= 0.0:
		return
	delta *= local_time_scale
	flash = maxf(0, flash - delta)
	if react_time > 0:
		react_time = maxf(0, react_time - delta)
		if react_type == "jab":
			react_offset = react_offset.move_toward(Vector2.ZERO, 20.0 * delta)
			react_tilt = move_toward(react_tilt, 0.0, 0.35 * delta)
		elif react_type == "cross":
			react_offset = react_offset.move_toward(Vector2.ZERO, 25.0 * delta)
			react_tilt = move_toward(react_tilt, 0.0, 0.4 * delta)
		elif react_type == "hook":
			react_offset = react_offset.move_toward(Vector2.ZERO, 20.0 * delta)
			react_tilt = move_toward(react_tilt, 0.0, 0.7 * delta)
	else:
		react_offset = Vector2.ZERO
		react_tilt = 0.0
	queue_redraw()

func set_local_time_scale(scale: float) -> void:
	local_time_scale = maxf(scale, 0.0)

func _draw() -> void:
	draw_set_transform(react_offset, react_tilt, Vector2.ONE)
	var flash_weight := clampf(flash / 0.08, 0.0, 1.0)
	var color := Color("826447").lerp(Color.WHITE, flash_weight)
	draw_rect(Rect2(-3, -57, 6, 57), Color("433e35"))
	draw_rect(Rect2(-14, -43, 28, 7), Color("554937"))
	draw_rect(Rect2(-9, -51, 18, 32), Color("252e2b"))
	draw_rect(Rect2(-7, -50, 14, 29), color)
	draw_rect(Rect2(-8, -46, 16, 3), Color("c8ad70"))
	draw_rect(Rect2(-8, -28, 16, 3), Color("c8ad70"))
	draw_circle(Vector2(0, -36), 4, Color("423e34"))
	draw_circle(Vector2(0, -36), 2, Color("ba7950"))
	draw_rect(Rect2(-12, -3, 24, 4), Color("534b39"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
