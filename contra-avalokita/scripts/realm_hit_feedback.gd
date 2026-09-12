class_name RealmHitFeedback
extends Node2D
const Glyphs = preload("res://scripts/six_realm_glyphs.gd")
@export var lifetime := 0.8
@export var rise_distance := 16.0
@export var glyph_scale := .65
@export var digit_spacing := 16.0
@export var max_popups := 24
@export var ink := Color("edf5f3")
var popups: Array[Dictionary] = []

static func emit_hit(target: Node2D, damage: float, offset := Vector2(0,-65)) -> void:
	var host := target.get_tree().root
	var manager := host.get_node_or_null("RealmHitFeedback")
	if manager == null:
		manager = load("res://scripts/realm_hit_feedback.gd").new()
		manager.name = "RealmHitFeedback"
		manager.z_index = 80
		host.add_child(manager)
	manager.add_number(target.to_global(offset),damage,target.get_instance_id())

func add_number(origin: Vector2, value: float, owner_id: int = 0) -> void:
	var stack := 0
	for popup in popups:
		if popup.owner == owner_id and popup.age < .25: stack += 1
	if popups.size() >= max_popups: popups.pop_front()
	popups.append({"origin":origin+Vector2(stack*5,-stack*18),"digits":Glyphs.number_tokens(value),"age":0.0,"owner":owner_id})
	queue_redraw()

func _process(delta: float) -> void:
	for popup in popups: popup.age += delta
	popups = popups.filter(func(popup: Dictionary) -> bool: return popup.age < lifetime)
	queue_redraw()

func _draw() -> void:
	for popup in popups:
		var progress: float = popup.age/lifetime
		var color := ink
		color.a *= 1.0-smoothstep(.45,1.0,progress)
		var origin: Vector2 = popup.origin+Vector2(0,-rise_distance*(1-pow(1-progress,2)))
		for i in popup.digits.size():
			var pos := origin+Vector2((i-(popup.digits.size()-1)*.5)*digit_spacing,0)
			draw_set_transform(to_local(pos).round(),0,Vector2.ONE*glyph_scale)
			Glyphs.draw_symbol(self,popup.digits[i],color,1.0/glyph_scale)
	draw_set_transform(Vector2.ZERO)
