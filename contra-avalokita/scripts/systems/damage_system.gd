class_name DamageSystem
extends RefCounted

const HitEvent = preload("res://scripts/hit_event.gd")
const HitData = preload("res://scripts/combat/hit_data.gd")

static func normalize_hit_event(raw_data: Variant, fallback_direction: Vector2 = Vector2.RIGHT) -> HitEvent:
	if raw_data is HitEvent:
		return raw_data
	if raw_data is float or raw_data is int:
		return HitEvent.from_damage(float(raw_data), fallback_direction)
	if raw_data is Object and "damage" in raw_data:
		var dir := raw_data.direction if "direction" in raw_data else fallback_direction
		return HitEvent.from_damage(float(raw_data.damage), dir)
	return HitEvent.new()

static func calculate_block(event: HitEvent, victim: Node, is_frontal: bool) -> Dictionary:
	var is_blocking: bool = victim.has_method("is_blocking") and victim.is_blocking()
	if is_blocking and is_frontal:
		var is_armed: bool = victim.has_method("is_armed") and victim.is_armed()
		var block_dmg_mult := 0.15 if is_armed else 0.35
		var block_poise_mult := 0.30 if is_armed else 0.50
		var actual_dmg := event.damage * block_dmg_mult
		var actual_poise := event.poise_damage * block_poise_mult
		return {
			"is_blocked": true,
			"damage": actual_dmg,
			"poise_damage": actual_poise
		}
	return {
		"is_blocked": false,
		"damage": event.damage,
		"poise_damage": event.poise_damage
	}

static func calculate_critical(event: HitEvent, victim: Node = null) -> bool:
	if event.hit_region == &"HEAD":
		event.is_critical = true
		return true
	if victim and victim.get("reaction_state") in [&"HeavyHit", &"Knockdown"]:
		event.is_critical = true
		return true
	return false

static func evaluate_poise_break(current_stability: float, poise_damage: float) -> bool:
	return (current_stability - poise_damage) <= 0.0

static func apply_damage(victim: Node, event: HitEvent, actual_damage: float) -> float:
	if not is_instance_valid(victim):
		return 0.0
	if "health" in victim:
		victim.health = maxf(victim.health - actual_damage, 0.0)
	elif victim.has_method("damage"):
		victim.damage(actual_damage)
	
	event.damage_dealt = actual_damage
	if victim.has_signal("damaged"):
		victim.damaged.emit(actual_damage)
		
	var ks: Node = null
	if victim.is_inside_tree() and victim.get_tree() and victim.get_tree().root:
		ks = victim.get_tree().get_first_node_in_group(&"score_system")
	if ks and ks.has_method("record_hit"):
		ks.record_hit(victim, event, actual_damage)
		
	var feedback = load("res://scripts/realm_hit_feedback.gd")
	if feedback and feedback.has_method("emit_hit"):
		feedback.emit_hit(victim, actual_damage)
		
	return actual_damage
