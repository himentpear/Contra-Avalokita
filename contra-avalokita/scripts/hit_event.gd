class_name HitEvent
extends "res://scripts/combat/hit_data.gd"

var attack_name: StringName = &""
var attack_token := 0
var score_tags: Array[StringName] = []

var damage_dealt: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var impact_point: Vector2 = Vector2.ZERO
var impact_force: float = 80.0
var poise_damage: float = 15.0
var hit_type: StringName = &"LightHit" # &"MicroHit", &"LightHit", &"HeavyHit", &"AirHit", &"Knockdown"
var attacker_velocity: Vector2 = Vector2.ZERO
var hit_region: StringName = &"UPPER_TORSO" # &"HEAD", &"UPPER_TORSO", &"LOWER_TORSO", &"LEG"
var target_push_distance: float = 2.5
var attacker_drag_ratio: float = 0.40
var camera_shake_strength: float = 0.0
var slash_tangent: Vector2 = Vector2.ZERO

func _init(
	p_damage: float = 10.0,
	p_direction: Vector2 = Vector2.RIGHT,
	p_impact_point: Vector2 = Vector2.ZERO,
	p_impact_force: float = 80.0,
	p_poise_damage: float = 15.0,
	p_hit_type: StringName = &"LightHit",
	p_weapon_type: StringName = &"unarmed",
	p_hit_region: StringName = &"UPPER_TORSO"
) -> void:
	damage = p_damage
	impact = 0.90 if p_hit_type in [&"HeavyHit", &"Knockdown"] or damage >= 20.0 else (0.30 if p_hit_type == &"MicroHit" else 0.50)
	direction = p_direction.normalized() if p_direction.length_squared() > 0.0001 else Vector2.RIGHT
	impact_point = p_impact_point
	impact_force = p_impact_force
	poise_damage = p_poise_damage
	hit_type = p_hit_type
	weapon_type = p_weapon_type
	hit_region = p_hit_region
	if hit_type == &"HeavyHit" or hit_type == &"Knockdown" or damage >= 20.0:
		target_push_distance = 4.0
		attacker_drag_ratio = 0.50
		camera_shake_strength = 0.0
	elif hit_type == &"MicroHit":
		target_push_distance = 1.0
		attacker_drag_ratio = 0.20
		camera_shake_strength = 0.0
	else:
		target_push_distance = 2.2
		attacker_drag_ratio = 0.38
		camera_shake_strength = 0.0

static func from_damage(amount: float, dir: Vector2 = Vector2.RIGHT) -> HitEvent:
	var event := HitEvent.new()
	event.damage = amount
	event.direction = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	event.impact_force = clampf(amount * 8.0, 40.0, 220.0)
	event.poise_damage = amount * 1.5
	event.hit_type = &"LightHit" if amount < 20.0 else &"HeavyHit"
	event.hit_region = &"UPPER_TORSO"
	if event.hit_type == &"HeavyHit":
		event.impact = 0.90
		event.target_push_distance = 4.0
		event.attacker_drag_ratio = 0.50
		event.camera_shake_strength = 0.0
	else:
		event.impact = 0.5
		event.target_push_distance = 2.2
		event.attacker_drag_ratio = 0.38
		event.camera_shake_strength = 0.0
	return event
