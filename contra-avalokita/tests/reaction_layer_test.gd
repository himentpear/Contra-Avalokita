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
	var arena := load("res://tests/character/test_arena.tscn").instantiate() as Node2D
	root.add_child(arena)
	var p: MudCharacter = arena.player
	p.player_controlled = false
	await ticks(12)

	# 1. Verify HitEvent Data Structure
	var event := HitEvent.new(12.0, Vector2(-1.0, 0.0), Vector2(100, 200), 90.0, 20.0, &"LightHit", &"unarmed", &"UPPER_TORSO", 0.03)
	check(event.damage == 12.0, "HitEvent damage stored")
	check(event.direction == Vector2.LEFT, "HitEvent normalized direction stored")
	check(event.poise_damage == 20.0, "HitEvent poise damage stored")
	check(event.hit_type == &"LightHit", "HitEvent hit_type stored")

	var from_dmg := HitEvent.from_damage(30.0, Vector2.RIGHT)
	check(from_dmg.damage == 30.0, "from_damage creates valid event")
	check(from_dmg.hit_type == &"HeavyHit", "from_damage >= 25.0 maps to HeavyHit")

	# 2. Backward Compatibility: float passed to receive_hit
	var initial_health := p.health
	var initial_stability := p.stability
	p.receive_hit(10.0)
	check(p.health == initial_health - 10.0, "receive_hit(float) deducts health")
	check(p.stability < initial_stability, "receive_hit(float) deducts poise/stability")
	check(p.has_reaction(), "receive_hit(float) triggers reaction layer")
	await ticks(15) # Wait for reaction to complete
	check(not p.has_reaction(), "Reaction completes and clears")

	# 3. Light Hit During Run: Locomotion is PRESERVED
	p.revive()
	p.facing = 1.0
	for i in 20:
		p.set_intent(1.0)
		await physics_frame
	check(p.state == &"Run", "Player enters Run state")
	var phase_before := p.rig.gait.phase

	# Hit player with LightHit while running
	var light_event := HitEvent.new(6.0, Vector2.LEFT, Vector2.ZERO, 50.0, 10.0, &"LightHit", &"unarmed", &"UPPER_TORSO")
	p.receive_hit(light_event)
	check(p.has_reaction() and p.reaction_state == &"LightHit", "Light hit activates LightHit reaction layer")
	check(p.state == &"Run", "Locomotion state remains Run during light hit (not interrupted)")

	# Advance frames while continuing to run
	for i in 8:
		p.set_intent(1.0)
		await physics_frame
	var phase_after := p.rig.gait.phase
	check(phase_after != phase_before, "Gait phase continues advancing smoothly during hit")
	await ticks(10)
	check(not p.has_reaction(), "Light hit reaction finishes cleanly")

	# 4. Heavy Hit / Stagger: Interrupts Active Attack
	p.revive()
	p.weapons.equip(null)
	p.sync_weapon_animation()
	await ticks(5)
	p.start_attack(0)
	await ticks(3)
	check(p.is_attacking(), "Player is currently attacking")

	var heavy_event := HitEvent.new(20.0, Vector2.LEFT, Vector2.ZERO, 120.0, 45.0, &"HeavyHit", &"blade", &"UPPER_TORSO")
	p.receive_hit(heavy_event)
	check(not p.is_attacking(), "Heavy hit successfully interrupts attack (is_attacking == false)")
	check(p.reaction_state == &"HeavyHit", "Reaction state is HeavyHit")
	check(p.action_state == &"None", "Action state reset to None")
	await ticks(25)
	check(not p.has_reaction(), "Heavy stagger completes recovery")

	# 5. Poise Break System: Multiple light hits break stability -> forces HeavyHit
	p.revive()
	p.stability = 15.0 # Set low stability to test breaking threshold
	var light_poise_hit := HitEvent.new(5.0, Vector2.LEFT, Vector2.ZERO, 50.0, 20.0, &"LightHit", &"unarmed", &"UPPER_TORSO")
	p.receive_hit(light_poise_hit)
	check(p.reaction_state == &"HeavyHit", "Depleting poise to 0 forces HeavyHit stagger even on light attack")

	# 6. Air Hit: Airborne character receives hit without floor clamping
	p.revive()
	p.position = Vector2(285, 200) # In the air
	p.velocity = Vector2(0, -100)
	await ticks(2)
	check(not p.is_on_floor(), "Player is airborne")
	var air_event := HitEvent.new(8.0, Vector2.RIGHT, Vector2.ZERO, 90.0, 15.0, &"LightHit", &"unarmed", &"UPPER_TORSO")
	p.receive_hit(air_event)
	check(p.reaction_state == &"AirHit", "Airborne hit triggers AirHit reaction tier")
	check(p.velocity.x > 50.0, "Knockback impulse applied to airborne velocity: vx=%.1f" % p.velocity.x)

	# 7. Directional & Regional Kinematics
	p.revive()
	p.position = Vector2(285, 281)
	p.velocity = Vector2.ZERO
	await ticks(6)

	var head_bone: Bone2D = p.skeleton.get_node("Pelvis/Torso/Head")
	var torso_bone: Bone2D = p.skeleton.get_node("Pelvis/Torso")
	var initial_head_rot := head_bone.rotation
	var initial_torso_rot := torso_bone.rotation

	# Head hit from front (dir = LEFT when facing RIGHT)
	var head_hit := HitEvent.new(8.0, Vector2.LEFT, Vector2.ZERO, 60.0, 15.0, &"LightHit", &"unarmed", &"HEAD")
	p.receive_hit(head_hit)
	await ticks(6) # Local hitstop completes before the independent reaction advances.
	check(p.has_reaction(), "Head reaction active during peak window")
	check(head_bone.rotation != initial_head_rot, "Head bone rotates under head hit reaction: rot=%.3f" % head_bone.rotation)
	await ticks(15)

	# 8. SDF Continuous Field Deformation (Impact Dent & Ripple)
	p.revive()
	var sdf_hit := HitEvent.new(10.0, Vector2.LEFT, Vector2(285, 250), 70.0, 15.0, &"LightHit", &"unarmed", &"UPPER_TORSO")
	p.receive_hit(sdf_hit)
	check(p.body_renderer.impact_depth > 0.5, "SDF impact depth activated: %.2f" % p.body_renderer.impact_depth)
	await ticks(18)
	check(p.body_renderer.impact_depth < 0.1, "SDF impact depth smoothly decays to 0: %.2f" % p.body_renderer.impact_depth)

	# Cleanup
	arena.queue_free()
	await process_frame
	print("REACTION LAYER RESULT: ", errors, " failures")
	quit(1 if errors else 0)
