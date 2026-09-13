extends SceneTree

class LocalTimeActor extends Node:
	var local_scale := 1.0

	func set_local_time_scale(scale: float) -> void:
		local_scale = scale


var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func run() -> void:
	var manager := root.get_node("HitstopManager")
	manager.clear_all_stops()
	var attacker := LocalTimeActor.new()
	var victim := LocalTimeActor.new()
	root.add_child(attacker)
	root.add_child(victim)

	var hit := HitData.new()
	hit.attacker = attacker
	hit.victim = victim
	hit.impact = 0.50
	hit.weapon_type = &"slash"
	hit.bypass_frequency_decay = true
	var strength: float = manager.calculate_hitstop_strength(hit)
	check(is_equal_approx(strength, 0.50), "Slash strength preserves authored impact")
	check(is_equal_approx(manager.calculate_attacker_stop(hit, strength), 0.031875), "Attacker duration is 75% of victim")
	check(is_equal_approx(manager.calculate_victim_stop(hit, strength), 0.0425), "Impact 0.50 maps to 42.5ms victim stop")
	check(manager.calculate_world_stop(hit, strength) == 0.0, "Light hit leaves the world running")

	manager.request_hitstop(hit)
	check(attacker.local_scale == 0.0 and victim.local_scale == 0.0, "Confirmed hit freezes attacker and victim locally")
	var first_remaining: float = manager.active_actor_stops[victim.get_instance_id()]["remaining"]
	hit.impact = 1.20
	manager.request_hitstop(hit)
	var extended_remaining: float = manager.active_actor_stops[victim.get_instance_id()]["remaining"]
	check(extended_remaining > first_remaining, "Overlapping hitstop extends with max remaining duration")

	var multi := HitData.new()
	multi.impact = 1.0
	multi.weapon_type = &"slash"
	multi.hit_index = 2
	check(is_equal_approx(manager.calculate_hitstop_strength(multi), 0.36), "Third target receives multiplicative multi-hit decay")

	manager.actor_last_hitstop.erase(victim.get_instance_id())
	check(manager.get_frequency_modifier(victim) == 1.0, "First target hit gets full frequency weight")
	check(manager.get_frequency_modifier(victim) == 0.25, "Sub-50ms repeat hit decays to 25%")
	manager.actor_last_hitstop[victim.get_instance_id()] = Time.get_ticks_usec() * 0.000001 - 0.075
	check(manager.get_frequency_modifier(victim) == 0.50, "50-100ms repeat hit decays to 50%")

	var world_actor := LocalTimeActor.new()
	var ui_actor := LocalTimeActor.new()
	world_actor.add_to_group(manager.WORLD_GROUP)
	root.add_child(world_actor)
	root.add_child(ui_actor)
	manager.request_manual(null, null, 0.0, 0.0, 0.025)
	check(world_actor.local_scale == 0.0 and ui_actor.local_scale == 1.0, "World group freezes without stopping unrelated UI")

	manager.clear_all_stops()
	check(attacker.local_scale == 1.0 and victim.local_scale == 1.0 and world_actor.local_scale == 1.0, "Clearing restores every valid local clock")
	manager.apply_actor_stop(world_actor, 0.050)
	root.remove_child(world_actor)
	check(world_actor.local_scale == 1.0 and not manager.active_actor_stops.has(world_actor.get_instance_id()), "Tree removal restores local time and removes the stop entry")
	root.add_child(world_actor)
	attacker.queue_free()
	victim.queue_free()
	world_actor.queue_free()
	ui_actor.queue_free()
	await process_frame
	check(manager.active_actor_stops.is_empty(), "Freed actors leave no active hitstop entries")

	print("HITSTOP MANAGER RESULT: ", failures, " failures")
	quit(1 if failures else 0)
