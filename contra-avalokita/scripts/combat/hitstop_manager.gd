extends Node

signal hitstop_started(actor: Node, strength: float, hit_data: HitData)
signal hitstop_finished(actor: Node)
signal world_hitstop_started(duration: float, hit_data: HitData)
signal world_hitstop_finished

@export var debug_hitstop := false

const FREQUENCY_FULL_INTERVAL := 0.100
const FREQUENCY_HALF_INTERVAL := 0.050
const WORLD_GROUP: StringName = &"hitstop_world"

var active_actor_stops: Dictionary = {}
var actor_last_hitstop: Dictionary = {}
var _world_remaining := 0.0
var _current_scene_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_current_scene_id = _get_current_scene_id()
	get_tree().node_removed.connect(_on_node_removed)


func _process(delta: float) -> void:
	var scene_id := _get_current_scene_id()
	if scene_id != _current_scene_id:
		clear_all_stops()
		_current_scene_id = scene_id

	for instance_id in active_actor_stops.keys():
		var entry: Dictionary = active_actor_stops[instance_id]
		var actor_ref: WeakRef = entry["actor"]
		var actor := actor_ref.get_ref() as Node
		if not is_instance_valid(actor) or not actor.is_inside_tree():
			active_actor_stops.erase(instance_id)
			actor_last_hitstop.erase(instance_id)
			continue
		var remaining: float = float(entry["remaining"]) - delta
		if remaining <= 0.0:
			_finish_actor_stop(instance_id, actor)
		else:
			entry["remaining"] = remaining
			active_actor_stops[instance_id] = entry

	if _world_remaining > 0.0:
		_world_remaining = maxf(0.0, _world_remaining - delta)
		if _world_remaining == 0.0:
			world_hitstop_finished.emit()


func request_hitstop(hit: HitData) -> void:
	if hit == null:
		return

	var strength := calculate_hitstop_strength(hit)
	if not hit.bypass_frequency_decay and is_instance_valid(hit.victim):
		strength *= get_frequency_modifier(hit.victim)

	var attacker_duration := calculate_attacker_stop(hit, strength)
	var victim_duration := calculate_victim_stop(hit, strength)
	var world_duration := calculate_world_stop(hit, strength)

	if is_instance_valid(hit.attacker):
		apply_actor_stop(hit.attacker, attacker_duration, strength, hit)
	if is_instance_valid(hit.victim):
		apply_actor_stop(hit.victim, victim_duration, strength, hit)
	if world_duration > 0.0:
		apply_world_stop(world_duration, strength, hit)

	if debug_hitstop:
		print(
			"[Hitstop]\nweapon = %s\nimpact = %.2f\nstrength = %.2f\nattacker = %dms\nvictim = %dms\nworld = %dms\ncritical = %s\nkill = %s\nhit_index = %d"
			% [hit.weapon_type, hit.impact, strength, roundi(attacker_duration * 1000.0),
			roundi(victim_duration * 1000.0), roundi(world_duration * 1000.0),
			str(hit.is_critical), str(hit.is_kill), hit.hit_index]
		)


func calculate_hitstop_strength(hit: HitData) -> float:
	var strength := maxf(hit.impact, 0.0)
	strength *= get_weapon_modifier(hit.weapon_type)
	if hit.is_critical:
		strength *= 1.35
	if hit.is_kill:
		strength *= 1.30
	if hit.is_armor_break:
		strength *= 1.50
	if hit.is_parry:
		strength *= 1.65
	strength *= pow(0.60, maxi(hit.hit_index, 0))
	return strength


func get_weapon_modifier(type: StringName) -> float:
	match type:
		&"punch", &"unarmed":
			return 0.80
		&"slash", &"blade":
			return 1.00
		&"pierce":
			return 0.75
		&"blunt":
			return 1.30
		&"bullet", &"projectile":
			return 0.45
		&"shotgun":
			return 0.90
		&"explosion":
			return 1.40
		_:
			return 1.0


func strength_to_duration(strength: float) -> float:
	return clampf(0.015 + strength * 0.055, 0.015, 0.160)


func calculate_attacker_stop(hit: HitData, strength: float) -> float:
	if hit.attacker_stop_override >= 0.0:
		return hit.attacker_stop_override
	return strength_to_duration(strength) * 0.75


func calculate_victim_stop(hit: HitData, strength: float) -> float:
	if hit.victim_stop_override >= 0.0:
		return hit.victim_stop_override
	var base := strength_to_duration(strength)
	return base * 1.35 if hit.is_parry else base


func calculate_world_stop(hit: HitData, strength: float) -> float:
	if hit.world_stop_override >= 0.0:
		return hit.world_stop_override
	if hit.is_parry:
		return strength_to_duration(strength) * 0.50
	var exceptional := hit.is_critical or hit.is_kill or hit.is_armor_break or hit.weapon_type == &"explosion"
	if strength < 0.9 and not exceptional:
		return 0.0
	var ratio := 0.40 if hit.weapon_type == &"explosion" else 0.25
	return strength_to_duration(strength) * ratio


func get_frequency_modifier(target: Node) -> float:
	if not is_instance_valid(target):
		return 1.0
	var instance_id := target.get_instance_id()
	var now := Time.get_ticks_usec() * 0.000001
	var modifier := 1.0
	if actor_last_hitstop.has(instance_id):
		var interval: float = now - float(actor_last_hitstop[instance_id])
		if interval < FREQUENCY_HALF_INTERVAL:
			modifier = 0.25
		elif interval < FREQUENCY_FULL_INTERVAL:
			modifier = 0.50
	actor_last_hitstop[instance_id] = now
	return modifier


func apply_actor_stop(actor: Node, duration: float, strength: float = 1.0, hit: HitData = null) -> void:
	if not is_instance_valid(actor) or duration <= 0.0 or not actor.has_method("set_local_time_scale"):
		return
	var instance_id := actor.get_instance_id()
	var was_active := active_actor_stops.has(instance_id)
	var remaining := duration
	if was_active:
		remaining = maxf(float(active_actor_stops[instance_id]["remaining"]), duration)
	active_actor_stops[instance_id] = {
		"actor": weakref(actor),
		"remaining": remaining,
	}
	actor.call("set_local_time_scale", 0.0)
	hitstop_started.emit(actor, strength, hit)


func apply_world_stop(duration: float, strength: float = 1.0, hit: HitData = null) -> void:
	if duration <= 0.0:
		return
	var was_active := _world_remaining > 0.0
	_world_remaining = maxf(_world_remaining, duration)
	for node in get_tree().get_nodes_in_group(WORLD_GROUP):
		apply_actor_stop(node, duration, strength, hit)
	if not was_active:
		world_hitstop_started.emit(duration, hit)


func request_manual(
	attacker: Node = null,
	victim: Node = null,
	attacker_duration: float = 0.0,
	victim_duration: float = 0.0,
	world_duration: float = 0.0,
	strength: float = 1.0
) -> void:
	var hit := HitData.new()
	hit.attacker = attacker
	hit.victim = victim
	hit.impact = strength
	hit.weapon_type = &"special"
	hit.attacker_stop_override = maxf(attacker_duration, 0.0)
	hit.victim_stop_override = maxf(victim_duration, 0.0)
	hit.world_stop_override = maxf(world_duration, 0.0)
	hit.bypass_frequency_decay = true
	request_hitstop(hit)


func request_parry(player: Node, enemy: Node) -> void:
	var hit := HitData.new()
	hit.attacker = player
	hit.victim = enemy
	hit.impact = 0.65
	hit.weapon_type = &"slash"
	hit.is_parry = true
	hit.bypass_frequency_decay = true
	request_hitstop(hit)


func clear_actor_stop(actor: Node) -> void:
	if not is_instance_valid(actor):
		return
	var instance_id := actor.get_instance_id()
	if active_actor_stops.has(instance_id):
		_finish_actor_stop(instance_id, actor)
	actor_last_hitstop.erase(instance_id)


func clear_all_stops() -> void:
	for instance_id in active_actor_stops.keys():
		var entry: Dictionary = active_actor_stops[instance_id]
		var actor_ref: WeakRef = entry["actor"]
		var actor := actor_ref.get_ref() as Node
		if is_instance_valid(actor) and actor.has_method("set_local_time_scale"):
			actor.call("set_local_time_scale", 1.0)
	active_actor_stops.clear()
	actor_last_hitstop.clear()
	if _world_remaining > 0.0:
		_world_remaining = 0.0
		world_hitstop_finished.emit()


func _finish_actor_stop(instance_id: int, actor: Node) -> void:
	active_actor_stops.erase(instance_id)
	if is_instance_valid(actor) and actor.has_method("set_local_time_scale"):
		actor.call("set_local_time_scale", 1.0)
		hitstop_finished.emit(actor)


func _on_node_removed(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var instance_id := node.get_instance_id()
	if active_actor_stops.has(instance_id):
		active_actor_stops.erase(instance_id)
		if node.has_method("set_local_time_scale"):
			node.call("set_local_time_scale", 1.0)
			hitstop_finished.emit(node)
	actor_last_hitstop.erase(instance_id)


func _get_current_scene_id() -> int:
	var scene := get_tree().current_scene
	return scene.get_instance_id() if is_instance_valid(scene) else 0
