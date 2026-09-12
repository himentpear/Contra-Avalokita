class_name HitEvent
extends RefCounted

var attacker: Node
var attack_name: StringName = &""
var attack_token := 0
var score_tags: Array[StringName] = []

var damage: float = 10.0
var direction: Vector2 = Vector2.RIGHT
var impact_point: Vector2 = Vector2.ZERO
var impact_force: float = 80.0
var poise_damage: float = 15.0
var hit_type: StringName = &"LightHit" # &"MicroHit", &"LightHit", &"HeavyHit", &"AirHit", &"Knockdown"
var attacker_velocity: Vector2 = Vector2.ZERO
var weapon_type: StringName = &"unarmed" # &"unarmed", &"blade", &"projectile"
var hit_region: StringName = &"UPPER_TORSO" # &"HEAD", &"UPPER_TORSO", &"LOWER_TORSO", &"LEG"
var hit_stop_duration: float = 0.033
var hit_stop_frames: int = 1
var impact_strength: float = 0.5
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
	p_hit_region: StringName = &"UPPER_TORSO",
	p_hit_stop_duration: float = 0.033
) -> void:
	damage = p_damage
	direction = p_direction.normalized() if p_direction.length_squared() > 0.0001 else Vector2.RIGHT
	impact_point = p_impact_point
	impact_force = p_impact_force
	poise_damage = p_poise_damage
	hit_type = p_hit_type
	weapon_type = p_weapon_type
	hit_region = p_hit_region
	hit_stop_duration = p_hit_stop_duration
	if hit_type == &"HeavyHit" or hit_type == &"Knockdown" or damage >= 20.0:
		impact_strength = 1.0
		hit_stop_frames = 2
		hit_stop_duration = 0.066
		target_push_distance = 4.0
		attacker_drag_ratio = 0.50
		camera_shake_strength = 0.0
	elif hit_type == &"MicroHit":
		impact_strength = 0.2
		hit_stop_frames = 1
		hit_stop_duration = 0.025
		target_push_distance = 1.0
		attacker_drag_ratio = 0.20
		camera_shake_strength = 0.0
	else:
		impact_strength = 0.5
		hit_stop_frames = 1
		hit_stop_duration = 0.033
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
		event.impact_strength = 1.0
		event.hit_stop_frames = 2
		event.hit_stop_duration = 0.066
		event.target_push_distance = 4.0
		event.attacker_drag_ratio = 0.50
		event.camera_shake_strength = 0.0
	else:
		event.impact_strength = 0.5
		event.hit_stop_frames = 1
		event.hit_stop_duration = 0.033
		event.target_push_distance = 2.2
		event.attacker_drag_ratio = 0.38
		event.camera_shake_strength = 0.0
	return event
