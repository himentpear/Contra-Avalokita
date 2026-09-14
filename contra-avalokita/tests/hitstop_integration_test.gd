extends SceneTree

var failures := 0
var manager: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func make_actor(position := Vector2(320, 200)) -> MudCharacter:
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	actor.position = position
	root.add_child(actor)
	return actor

func wait_for_resume(actor: MudCharacter) -> void:
	for frame in 60:
		if actor.local_time_scale > 0.0:
			return
		await process_frame

func cleanup_actor(actor: MudCharacter) -> void:
	manager.clear_actor_stop(actor)
	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	await process_frame

func run() -> void:
	manager = root.get_node("HitstopManager")
	manager.clear_all_stops()

	var slash := make_actor()
	await physics_frame
	slash.start_attack(0)
	await physics_frame
	var slash_time := slash.attack_time
	var slash_hit := HitData.new()
	slash_hit.attacker = slash
	slash_hit.impact = 0.5
	slash_hit.weapon_type = &"slash"
	slash_hit.bypass_frequency_decay = true
	manager.request_hitstop(slash_hit)
	await physics_frame
	check(slash.local_time_scale == 0.0 and slash.attack_time == slash_time, "Normal slash freezes attack_time through manager local time")
	await wait_for_resume(slash)
	for frame in 2:
		await physics_frame
	check(slash.local_time_scale == 1.0 and slash.attack_time > slash_time, "Normal slash resumes attack normally")

	slash.start_attack(2)
	slash.attack_time = slash.attack_duration * 0.54
	var heavy_hold_time := slash.attack_time
	manager.apply_actor_stop(slash, 0.05)
	await physics_frame
	check(slash.attack_time == heavy_hold_time, "Attack3 authored visual hold does not double-advance during Hitstop")
	await wait_for_resume(slash)

	manager.apply_actor_stop(slash, 0.02)
	manager.apply_actor_stop(slash, 0.04)
	manager.apply_actor_stop(slash, 0.03)
	check(manager.active_actor_stops[slash.get_instance_id()]["remaining"] >= 0.039, "Rapid confirmed hits merge into one max-duration stop")
	await wait_for_resume(slash)
	check(slash.local_time_scale == 1.0, "Rapid hitstop sequence cannot leave a permanent freeze")

	slash.start_attack(1)
	var heavy := HitEvent.new(10.0, Vector2.LEFT, slash.global_position, 100.0, 90.0, &"HeavyHit", &"blade")
	slash.receive_hit(heavy)
	var reaction_time := slash.reaction_time
	await physics_frame
	check(not slash.is_attacking() and slash.reaction_time == reaction_time, "HeavyHit cancels Attack and freezes Reaction timing")
	await wait_for_resume(slash)
	for frame in 2:
		await physics_frame
	check(slash.reaction_time > reaction_time, "HeavyHit reaction resumes after Hitstop")
	await cleanup_actor(slash)

	var killed := make_actor()
	await physics_frame
	killed.health = 1.0
	var fatal := HitEvent.new(5.0, Vector2.LEFT)
	fatal.attacker = null
	killed.receive_hit(fatal)
	check(killed.state == &"Dead" and killed.local_time_scale == 0.0, "Kill enters Death ownership while manager holds local time")
	await wait_for_resume(killed)
	check(killed.local_time_scale == 1.0, "Kill hitstop restores the dead actor clock")
	await cleanup_actor(killed)

	var wall_actor := make_actor()
	await physics_frame
	wall_actor.wall_side = 1.0
	wall_actor.wall_coyote_side = 1.0
	wall_actor.wall_coyote_left = 0.1
	wall_actor.move_intent = 0.0
	wall_actor._start_wall_jump()
	wall_actor.wall_action_time = wall_actor.wall_push_duration
	wall_actor._update_wall_before_move(0.0)
	var wall_hit := HitEvent.new(5.0, Vector2.LEFT, wall_actor.global_position, 60.0, 10.0, &"LightHit", &"unarmed")
	wall_actor.receive_hit(wall_hit)
	var frozen_wall_time := wall_actor.wall_action_time
	var frozen_reaction_time := wall_actor.reaction_time
	await physics_frame
	check(wall_actor.wall_action == &"None" and wall_actor.wall_action_time == frozen_wall_time, "WallJump hit clears Wall IK and freezes wall timing")
	check(wall_actor.reaction_time == frozen_reaction_time, "WallJump hit freezes reaction timing")
	await wait_for_resume(wall_actor)

	wall_actor.revive()
	wall_actor.movement_assist.coyote_available = true
	wall_actor.movement_assist.coyote_remaining = 0.08
	wall_actor.movement_assist.jump_buffer_remaining = 0.06
	wall_actor.start_attack(0)
	var coyote_before := wall_actor.movement_assist.coyote_remaining
	var buffer_before := wall_actor.movement_assist.jump_buffer_remaining
	manager.apply_actor_stop(wall_actor, 0.04)
	await physics_frame
	check(wall_actor.movement_assist.coyote_remaining == coyote_before and wall_actor.movement_assist.jump_buffer_remaining == buffer_before, "Coyote and jump-buffer timers pause during attack Hitstop")
	await wait_for_resume(wall_actor)
	await physics_frame
	check(wall_actor.local_time_scale == 1.0 and wall_actor.movement_assist.coyote_remaining < coyote_before, "Movement-assist clocks resume after Hitstop")
	await cleanup_actor(wall_actor)

	manager.clear_all_stops()
	print("HITSTOP INTEGRATION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
