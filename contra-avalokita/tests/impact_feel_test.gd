extends SceneTree
var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		errors += 1
		push_error("FAIL: " + message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	var arena := load("res://scenes/test_arena.tscn").instantiate() as Node2D
	root.add_child(arena)
	var p: MudCharacter = arena.player
	var dummy = arena.dummy
	p.player_controlled = false
	await ticks(12)

	# 1. Attacker & Target Hit Stop Synchronization
	p.weapons.equip(null)
	p.sync_weapon_animation()
	p.position = Vector2(370, 281)
	p.facing = 1.0
	p.velocity = Vector2.ZERO
	await ticks(6)

	# Start Jab punch
	p.start_attack(0)
	await ticks(5) # Reach active window and land hit on dummy
	var hitstop_manager := root.get_node("HitstopManager")
	check(p.local_time_scale == 0.0, "Attacker receives manager-owned local hitstop")
	check(hitstop_manager.active_actor_stops.has(p.get_instance_id()), "HitstopManager owns the active attacker stop")
	check(p.impact_accent_offset.x < 0.0, "Attacker shoulder/wrist receives backward resistance pulse: %.2f" % p.impact_accent_offset.x)
	check(p.hit_drag_timer > 0.0, "Attacker enters hit drag resistance window")
	check(p.hit_drag_ratio >= 0.35, "Attacker drag slows follow-through by >= 35%% (ratio=%.2f)" % p.hit_drag_ratio)

	# 2. Hitstop pauses the whole actor clock; drag resumes afterward.
	var prev_t := p.attack_time
	await physics_frame
	check(p.attack_time == prev_t, "Attack time frozen while local_time_scale is zero")
	while p.local_time_scale <= 0.0:
		await process_frame
	prev_t = p.attack_time
	p.advance_attack(1.0 / 30.0)
	var dt := p.attack_time - prev_t
	check(dt < (1.0 / 30.0) * 0.9, "Attack time progresses at reduced drag speed (dt=%.4f vs full=%.4f)" % [dt, 1.0/30.0])

	await ticks(20) # Finish punch

	# 3. Target Push-First Sequence (先推后塌)
	p.revive()
	p.position = Vector2(285, 281)
	await ticks(5)

	var hit_event := HitEvent.new(15.0, Vector2.RIGHT, Vector2.ZERO, 90.0, 25.0, &"LightHit", &"blade", &"UPPER_TORSO")
	p.receive_hit(hit_event)
	check(p.reaction_push_offset.x > 1.5, "Target immediately receives linear push offset along attack direction: dx=%.2f" % p.reaction_push_offset.x)
	
	# Check visual position on Frame +1:
	await ticks(1)
	var push_disp: float = p.pose_root.position.x if absf(p.pose_root.position.x) > 0.01 else p.visual.position.x
	check(push_disp > 1.0, "Target visual mesh displaced horizontally on Frame +1 before rotational bend: %.2f" % push_disp)

	# 4. SDF Contact Dent + Opposite Bulge
	check(p.body_renderer.impact_depth > 0.5, "SDF contact dent depth is active: %.2f" % p.body_renderer.impact_depth)
	check(p.body_renderer.impact_bulge_height > 0.5, "SDF opposite side bulge height is active: %.2f" % p.body_renderer.impact_bulge_height)
	check(p.body_renderer.impact_bulge_center.x != p.body_renderer.impact_center.x, "Bulge center is positioned on opposite side of body from impact")

	await ticks(18)
	check(p.body_renderer.impact_depth < 0.1, "SDF contact dent decayed: %.2f" % p.body_renderer.impact_depth)
	check(p.body_renderer.impact_bulge_height < 0.1, "SDF opposite bulge decayed: %.2f" % p.body_renderer.impact_bulge_height)

	# 5. Weapon Impact Flash on Blade Strike
	p.revive()
	p.weapons.equip(p.weapons.default_weapon)
	p.sync_weapon_animation()
	p.position = Vector2(370, 281)
	p.facing = 1.0
	await ticks(6)

	var sword: MudWeapon = p.weapons.current
	check(sword != null, "Sword equipped and active")
	var flash_detected := false
	p.set_intent(0, false, true)
	for i in 30:
		await physics_frame
		if sword.impact_flash_timer > 0.0:
			flash_detected = true
			break
	check(flash_detected, "1-frame Impact Flash triggered at contact point")
	await ticks(15)
	check(sword.impact_flash_timer == 0.0, "Impact Flash clears cleanly after contact")

	# 6. Directional Camera Shake (Disabled by default)
	check(not arena.camera_shake_enabled, "Directional camera shake is disabled by default")
	arena.trigger_camera_shake(Vector2.RIGHT, 2.5, 0.08)
	await process_frame
	check(arena.camera_shake_offset == Vector2.ZERO, "Camera shake offset remains ZERO when disabled")
	check(arena.position == Vector2.ZERO, "Arena position remains stable at ZERO")

	# Verify optional opt-in functionality
	arena.camera_shake_enabled = true
	arena.trigger_camera_shake(Vector2.RIGHT, 2.5, 0.08)
	await process_frame
	check(arena.camera_shake_offset.x != 0.0, "Camera shake activates only when explicitly enabled: %.1f" % arena.camera_shake_offset.x)
	await ticks(10)
	check(arena.camera_shake_offset == Vector2.ZERO, "Camera shake returns to exact neutral position (0, 0)")
	arena.camera_shake_enabled = false

	# Cleanup
	arena.queue_free()
	await process_frame
	print("IMPACT FEEL RESULT: ", errors, " failures")
	quit(1 if errors else 0)
