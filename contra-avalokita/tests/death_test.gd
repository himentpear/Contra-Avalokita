extends SceneTree
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena := load("res://scenes/test_arena.tscn").instantiate() as Node2D
	root.add_child(arena)
	var p: MudCharacter = arena.player
	p.player_controlled = false
	await ticks(10)
	check(p.is_on_floor() and p.state == &"Idle", "Player starts idle on floor")
	check(p.death_controller != null, "DeathController is attached to player")
	check(p.splatter != null, "PixelMudSplatter is attached to player")

	# 1. Non-lethal damage does not trigger death
	p.receive_hit(20.0)
	check(p.health == 80.0 and p.state != &"Dead", "Non-lethal hit reduces health without triggering death")

	# 2. Lethal hit triggers death sequence
	p.receive_hit(90.0)
	check(p.health == 0.0 and p.state == &"Dead", "Lethal hit triggers Dead state")
	var dc: MudDeathController = p.death_controller
	check(dc.current_phase == MudDeathController.DeathPhase.FATAL_PAUSE, "Phase 1: Death starts with FATAL_PAUSE")

	# 3. Input locking during death
	p.set_intent(1.0, true, true)
	await ticks(5)
	check(p.state == &"Dead", "Player cannot move, jump, or attack while dead")

	# 4. Support loss phase
	var t_pause := dc.death_duration * dc.pause_ratio
	var ticks_to_support := int(ceil((t_pause + 0.05) * 60.0))
	await ticks(ticks_to_support)
	check(dc.current_phase == MudDeathController.DeathPhase.SUPPORT_LOSS, "Phase 2: Transition into SUPPORT_LOSS")
	check(p.body_renderer.death_progress > 0.0, "Body renderer receives death progress")

	# 5. Collapse phase, splatter burst, weapon drop
	var t_collapse := dc.death_duration * (dc.pause_ratio + dc.support_loss_ratio)
	var ticks_to_collapse := int(ceil((t_collapse + 0.05) * 60.0))
	await ticks(ticks_to_collapse)
	check(dc.current_phase >= MudDeathController.DeathPhase.COLLAPSE, "Phase 3: Transition into COLLAPSE")
	check(dc.impact_triggered, "Impact triggered at collapse")
	check(p.splatter.active and p.splatter.droplets.size() > 0, "Pixel mud splatter burst active with crisp droplets")
	check(dc.weapon_dropped and p.weapons.weapon_dropped, "Weapon drops from character hands")

	# 6. Settle phase & Ground puddle expansion
	var t_settle := dc.death_duration * (dc.pause_ratio + dc.support_loss_ratio + dc.collapse_ratio)
	var ticks_to_settle := int(ceil((t_settle + 0.05) * 60.0))
	await ticks(ticks_to_settle)
	check(dc.current_phase >= MudDeathController.DeathPhase.PUDDLE_SETTLE, "Phase 4: Transition into PUDDLE_SETTLE")
	check(p.body_renderer.segment_cursor > 26, "Body renderer generated expanded puddle segments")

	# Check that pelvis has dropped significantly
	var pelvis_bone: Bone2D = p.skeleton.get_node("Pelvis") as Bone2D
	check(pelvis_bone.position.y > -10.0, "Skeleton pelvis collapsed to floor level: " + str(pelvis_bone.position.y))

	# 7. Finished phase
	await ticks(40)
	check(dc.current_phase == MudDeathController.DeathPhase.FINISHED, "Death sequence completes with FINISHED phase")
	check(dc.death_progress >= 1.0, "Death progress reaches 1.0")

	# 8. Reset restoration
	p.revive()
	await ticks(5)
	check(p.health == p.max_health and p.state == &"Idle", "Reset resurrects character to full health and Idle")
	check(dc.current_phase == MudDeathController.DeathPhase.NONE, "DeathController reset to NONE phase")

	print("DEATH RESULT: ", failures, " failures")
	quit(1 if failures else 0)
