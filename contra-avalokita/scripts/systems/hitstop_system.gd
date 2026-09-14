class_name HitstopSystem
extends RefCounted

const HitData = preload("res://scripts/combat/hit_data.gd")
const HitEvent = preload("res://scripts/hit_event.gd")

static func request_hitstop(event: HitData, caller: Node = null) -> void:
	if not event: return
	var manager: Node = null
	if caller and caller.is_inside_tree():
		manager = caller.get_node_or_null("/root/HitstopManager")
	elif Engine.has_singleton("HitstopManager"):
		manager = Engine.get_singleton("HitstopManager")
	
	if manager and manager.has_method("request_hitstop"):
		manager.request_hitstop(event)

static func clear_actor_hitstop(actor: Node) -> void:
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	var manager: Node = actor.get_node_or_null("/root/HitstopManager")
	if manager and manager.has_method("clear_actor_stop"):
		manager.clear_actor_stop(actor)
	elif actor.has_method("set_local_time_scale"):
		actor.set_local_time_scale(1.0)

static func calculate_hit_flash(event: HitData = null, base_duration: float = 0.090, base_peak: float = 0.95) -> Dictionary:
	var authored_impact := event.impact if event else 1.0
	var intensity := base_peak * clampf(0.65 + authored_impact * 0.25, 0.65, 1.0)
	if event and event.is_blocked:
		intensity *= 0.70
	if event and (event.is_critical or event.is_kill or event.is_armor_break or event.is_parry):
		intensity = base_peak
	var duration_scale := clampf(0.85 + authored_impact * 0.15, 0.85, 1.15)
	var duration := base_duration * duration_scale
	return {
		"intensity": intensity,
		"duration": duration
	}

static func trigger_camera_shake(caller: Node, direction: Vector2, strength: float, duration: float = 0.08) -> void:
	if not is_instance_valid(caller) or not caller.is_inside_tree():
		return
	var tree := caller.get_tree()
	if tree and tree.current_scene and tree.current_scene.has_method("trigger_camera_shake"):
		tree.current_scene.call("trigger_camera_shake", direction, strength, duration)
