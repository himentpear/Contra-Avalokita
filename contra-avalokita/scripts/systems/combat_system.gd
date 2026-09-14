class_name CombatSystem
extends RefCounted

const Faction = preload("res://scripts/entities/faction.gd")
const HitData = preload("res://scripts/combat/hit_data.gd")
const HitEvent = preload("res://scripts/hit_event.gd")
const DamageSystem = preload("res://scripts/systems/damage_system.gd")
const HitstopSystem = preload("res://scripts/systems/hitstop_system.gd")

static func process_hitbox_overlap(
	attacker: Node,
	hitbox: Area2D,
	target_area: Area2D,
	attack_info: Dictionary,
	hit_targets: Array[int]
) -> HitEvent:
	if not is_instance_valid(attacker) or not is_instance_valid(target_area):
		return null
		
	var victim: Node = target_area.get_meta("owner_character", null) if target_area.has_meta("owner_character") else target_area.get_parent()
	if victim == attacker:
		return null
		
	var id := target_area.get_instance_id()
	if hit_targets.has(id):
		return null
	hit_targets.append(id)
	
	var attacker_faction := Faction.get_faction_of(attacker)
	var victim_faction := Faction.get_faction_of(victim) if victim else Faction.Type.NEUTRAL
	if not Faction.is_hostile(attacker_faction, victim_faction) and victim_faction != Faction.Type.NEUTRAL:
		# Don't hit friendly non-neutral targets
		return null
		
	var facing: float = attacker.get("facing") if "facing" in attacker else 1.0
	var combo_stage: int = int(attack_info.get("combo_stage", 0))
	var event := HitEvent.new()
	event.attacker = attacker
	event.attack_name = attack_info.get("attack_name", &"Attack")
	event.attack_token = attack_info.get("attack_token", 0)
	event.damage = float(attack_info.get("damage", 8.0))
	event.direction = Vector2(facing, 0.0)
	event.attacker_velocity = attacker.velocity if "velocity" in attacker else Vector2.ZERO
	event.weapon_type = attack_info.get("weapon_type", &"punch")
	event.impact = float(attack_info.get("impact", 1.0))
	event.hit_index = hit_targets.size() - 1
	event.impact_point = hitbox.global_position if is_instance_valid(hitbox) else attacker.global_position
	
	# Populate hit parameters based on combo_stage or authored attack info
	if attack_info.has("poise_damage"):
		event.poise_damage = float(attack_info["poise_damage"])
		event.impact_force = float(attack_info.get("impact_force", 80.0))
		event.hit_region = attack_info.get("hit_region", &"UPPER_TORSO")
		event.hit_type = attack_info.get("hit_type", &"LightHit")
		event.target_push_distance = float(attack_info.get("target_push_distance", 2.2))
		event.attacker_drag_ratio = float(attack_info.get("attacker_drag_ratio", 0.40))
		event.camera_shake_strength = float(attack_info.get("camera_shake_strength", 0.0))
	elif combo_stage == 0:
		event.hit_type = &"LightHit"
		event.poise_damage = 12.0
		event.impact_force = 55.0
		event.hit_region = &"HEAD"
		event.target_push_distance = 1.8
		event.attacker_drag_ratio = 0.35
		event.camera_shake_strength = 0.0
	elif combo_stage == 1:
		event.hit_type = &"LightHit"
		event.poise_damage = 18.0
		event.impact_force = 90.0
		event.hit_region = &"UPPER_TORSO"
		event.target_push_distance = 2.5
		event.attacker_drag_ratio = 0.40
		event.camera_shake_strength = 0.0
	else:
		event.hit_type = &"HeavyHit"
		event.poise_damage = 35.0
		event.impact_force = 135.0
		event.hit_region = &"HEAD"
		event.target_push_distance = 4.0
		event.attacker_drag_ratio = 0.50
		event.camera_shake_strength = 0.0
		
	DamageSystem.calculate_critical(event, victim)
	
	if bool(attack_info.get("enable_camera_shake", false)):
		HitstopSystem.trigger_camera_shake(attacker, event.direction, event.camera_shake_strength)
		
	if target_area.has_method("receive_hit"):
		target_area.call("receive_hit", event)
	elif victim and victim.has_method("receive_hit"):
		victim.call("receive_hit", event)
		
	var splatter = attacker.get_node_or_null("Visual/PixelMudSplatter")
	if splatter and is_instance_valid(target_area):
		splatter.burst(target_area.global_position, 5)
		
	return event

static func calculate_knockback(event: HitEvent, is_airborne: bool) -> Vector2:
	var air_mult: float = 1.25 if is_airborne else 1.0
	return event.direction * (event.impact_force * air_mult)

static func resolve_reaction(event: HitEvent, victim: Node, is_airborne: bool, poise_broken: bool) -> Dictionary:
	var tier: StringName = event.hit_type
	if tier == &"Knockdown" or event.poise_damage >= 80.0:
		tier = &"Knockdown"
	elif poise_broken or tier == &"HeavyHit":
		tier = &"HeavyHit"
	elif is_airborne:
		tier = &"AirHit"
	elif tier == &"MicroHit":
		tier = &"MicroHit"
	else:
		tier = &"LightHit"
		
	var duration := 0.15
	match tier:
		&"MicroHit": duration = 0.08
		&"LightHit": duration = 0.15
		&"AirHit": duration = 0.20
		&"HeavyHit": duration = 0.35
		&"Knockdown": duration = 0.48
		_: duration = 0.15
		
	var intensity := clampf(event.impact_force / 80.0, 0.5, 2.2)
	var push_offset: Vector2 = event.direction * event.target_push_distance
	
	var impact_local := Vector2.ZERO
	if is_instance_valid(victim):
		if event.impact_point != Vector2.ZERO:
			impact_local = victim.to_local(event.impact_point)
		else:
			match event.hit_region:
				&"HEAD": impact_local = Vector2(0.0, -42.0)
				&"LOWER_TORSO", &"LEG": impact_local = Vector2(0.0, -18.0)
				_: impact_local = Vector2(0.0, -32.0)
				
	return {
		"tier": tier,
		"duration": duration,
		"intensity": intensity,
		"push_offset": push_offset,
		"impact_local": impact_local
	}

static func evaluate_combo(combo_stage: int, max_stages: int, combo_queued: bool) -> Dictionary:
	if combo_queued and combo_stage + 1 < max_stages:
		return {
			"continue_combo": true,
			"next_stage": combo_stage + 1
		}
	return {
		"continue_combo": false,
		"next_stage": 0
	}
