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

	# 1. Verify Punch Animations Exist and are Registered
	for i in range(1, 4):
		var anim_name := "Punch/Attack_%d" % i
		check(p.anim_player.has_animation(anim_name), "Animation %s exists in player" % anim_name)

	# 2. Unequip weapon to enter Unarmed / Boxing state
	p.weapons.equip(null)
	p.sync_weapon_animation()
	check(p.weapons.current == null and not p.is_armed(), "Player is unarmed")
	check(p.attack_animation() == &"Punch/Attack_1", "Default unarmed attack animation is Punch/Attack_1")

	# 3. Test Punch 1 (Lead Jab) against Training Dummy
	# Player at (370, 281), Dummy at (411, 283) -> dx = 41px, direct punching range
	p.position = Vector2(370, 281)
	p.facing = 1.0
	p.velocity = Vector2.ZERO
	p.set_intent(0.0)
	await ticks(6)
	
	var initial_hits: int = dummy.hit_count
	# Windup phase: request attack
	p.set_intent(0.0, false, true)
	await ticks(2)
	check(p.is_attacking() and p.action_state == &"Attack1", "Punch 1 initiated")
	check(not p.punch_hitbox.monitoring, "Windup has no punch damage before active window")
	
	# Active strike phase (0.08s - 0.20s -> around ticks 5-10 at 60Hz)
	await ticks(6)
	check(p.punch_hitbox.monitoring, "Punch 1 active window enables punch hitbox")
	check(p.punch_hitbox.global_position.x > p.global_position.x + 20, "Fist hitbox extends forward toward dummy: dx=%.1f" % (p.punch_hitbox.global_position.x - p.global_position.x))
	
	# Recovery phase (wait for punch 1 to finish, duration 0.34s = ~21 ticks)
	await ticks(18)
	check(dummy.hit_count == initial_hits + 1, "Punch 1 (Lead Jab) strikes dummy exactly once")
	check(not p.is_attacking(), "Punch 1 completes and recovers to idle")
	check(not p.punch_hitbox.monitoring, "Hitbox closes after punch completes")

	# 4. Test Single-Swing Deduplication (punching dummy again must hit exactly once)
	p.set_intent(0.0, false, true)
	await ticks(24)
	check(dummy.hit_count == initial_hits + 2, "Second punch strikes dummy exactly once (deduplication verified)")
	await ticks(6)

	# 5. Test 3-Stage Boxing Combo (Jab -> Cross -> Hook)
	# Punch 1 (Lead Jab)
	p.set_intent(0.0, false, true)
	await ticks(10)
	check(p.is_attacking() and p.combo_stage == 0, "Combo stage 0: Lead Jab")
	# Queue Punch 2 (Cross) during buffer window
	p.set_intent(0.0, false, true)
	await ticks(15)
	check(p.is_attacking() and p.combo_stage == 1, "Combo stage 1: Rear Cross triggered via combo buffer")
	check(p.attack_animation() == &"Punch/Attack_2", "Cross plays Punch/Attack_2")
	
	# Queue Punch 3 (Hook) during buffer window
	await ticks(10)
	p.set_intent(0.0, false, true)
	await ticks(20)
	check(p.is_attacking() and p.combo_stage == 2, "Combo stage 2: Lead Hook triggered via combo buffer")
	check(p.attack_animation() == &"Punch/Attack_3", "Hook plays Punch/Attack_3")

	# Wait for full combo recovery
	await ticks(38)
	check(not p.is_attacking(), "Full 3-stage boxing combo completes recovery")
	check(dummy.hit_count == initial_hits + 5, "All 3 combo punches landed hits on dummy (5 total)")
	await ticks(6)

	# 6. Test Symmetric Punch (Facing Left)
	# Move dummy to the left of player: player at (370, 281), dummy at (330, 283)
	dummy.position = Vector2(330, 283)
	p.facing = -1.0
	p.set_intent(0.0, false, true)
	await ticks(8)
	check(p.punch_hitbox.global_position.x < p.global_position.x - 15, "Fist hitbox extends to the left when facing left: dx=%.1f" % (p.punch_hitbox.global_position.x - p.global_position.x))
	await ticks(20)
	check(dummy.hit_count == initial_hits + 6, "Left-facing punch successfully strikes target")
	await ticks(6)

	# 7. Test Retreating Punch (Facing right, moving left -> Backstep + Punch)
	p.facing = 1.0
	p.start_attack(0)
	for f in 10:
		p.set_intent(-1.0, false, false)
		await physics_frame
	check(p.is_attacking(), "Retreating punch is attacking")
	check(p.is_retreating(), "Retreating punch registers is_retreating")
	check(p.anim_player.current_animation == &"Backstep_Unarmed", "Legs adopt Backstep_Unarmed during retreating punch")
	await ticks(15)

	# 8. Re-equip Sword: punch hitbox is disabled, sword hitbox reclaims attack
	p.weapons.equip(p.weapons.default_weapon)
	p.sync_weapon_animation()
	check(p.is_armed() and p.weapons.current != null, "Sword re-equipped")
	check(not p.punch_hitbox.monitoring, "Punch hitbox remains disabled when sword is equipped")
	check(p.attack_animation() == &"Blade/Attack_1", "Attack animation reverts to Blade/Attack_1")

	# Cleanup
	arena.queue_free()
	await process_frame
	print("PUNCH ATTACK RESULT: ", errors, " failures")
	quit(1 if errors else 0)
