extends Node2D
var hit_count := 0
var flash := 0.0

func _ready() -> void:
	var area := Area2D.new()
	area.name = "Hurtbox"
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("owner_character", self)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 50)
	collider.shape = shape
	collider.position.y = -30
	area.add_child(collider)
	add_child(area)

func receive_hit(_damage: float) -> void:
	hit_count += 1
	flash = 0.15

func _process(delta: float) -> void:
	flash = maxf(0, flash - delta)
	queue_redraw()

func _draw() -> void:
	var color := Color("f0dc9a") if flash > 0 else Color("826447")
	draw_rect(Rect2(-3, -57, 6, 57), Color("433e35"))
	draw_rect(Rect2(-14, -43, 28, 7), Color("554937"))
	draw_rect(Rect2(-9, -51, 18, 32), Color("252e2b"))
	draw_rect(Rect2(-7, -50, 14, 29), color)
	draw_rect(Rect2(-8, -46, 16, 3), Color("c8ad70"))
	draw_rect(Rect2(-8, -28, 16, 3), Color("c8ad70"))
	draw_circle(Vector2(0, -36), 4, Color("423e34"))
	draw_circle(Vector2(0, -36), 2, Color("ba7950"))
	draw_rect(Rect2(-12, -3, 24, 4), Color("534b39"))

