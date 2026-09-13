class_name CoyoteItemPickup
extends Area2D

signal collected(item: CoyoteItem)

@export var item: CoyoteItem
@export var content_id: StringName
var consumed := false
var _label: Label

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	collider.shape = shape
	add_child(collider)
	_label = Label.new()
	_label.position = Vector2(-34.0, -29.0)
	_label.custom_minimum_size.x = 68.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 7)
	add_child(_label)
	body_entered.connect(_on_body_entered)
	_refresh()
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if consumed or not body.has_method("obtain_item"): return
	var obtained := false
	if not content_id.is_empty() and body.has_method("obtain_content_item"):
		obtained = bool(body.call("obtain_content_item", content_id))
	if not obtained and item != null:
		body.call("obtain_item", item)
		obtained = true
	if not obtained: return
	consumed = true
	monitoring = false
	collected.emit(item)
	_refresh()
	queue_redraw()

func reset_pickup() -> void:
	consumed = false
	monitoring = true
	_refresh()
	queue_redraw()

func _refresh() -> void:
	if _label:
		_label.text = "已获得" if consumed else (item.display_name if item else String(content_id))
		_label.modulate = Color("71827b") if consumed else Color("dce8c2")

func _draw() -> void:
	var alpha := 0.24 if consumed else 1.0
	draw_circle(Vector2.ZERO, 9.0, Color(0.06, 0.10, 0.12, 0.9 * alpha))
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 20, Color(0.76, 0.84, 0.60, alpha), 1.0)
	draw_circle(Vector2.ZERO, 2.0, Color(0.95, 0.98, 0.90, alpha))
	draw_line(Vector2(-5.0, 13.0), Vector2(5.0, 13.0), Color(0.40, 0.52, 0.48, alpha), 2.0)
