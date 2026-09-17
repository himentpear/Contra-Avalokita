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
	p.player_controlled = false
	await ticks(12)

	var shoulder: Bone2D = p._upper_arm_front_bone
	var elbow: Bone2D = p._forearm_front_bone
	var hand: Bone2D = p._hand_front_bone
	var max_anatomical_reach := 24.0

	# 1. Tests for Facing Right (+1.0) and Facing Left (-1.0)
	for test_facing in [1.0, -1.0]:
		var facing_str := "FACING RIGHT (+1)" if test_facing > 0 else "FACING LEFT (-1)"
		var base_x := 370.0 if test_facing > 0 else 460.0

		# 1.1 Idle -> Attack1, Attack2, Attack3 with hits
		p.revive()
		p.weapons.equip(p.weapons.default_weapon)
		p.sync_weapon_animation()
		p.position = Vector2(base_x, 136)
		p.facing = test_facing
		p.velocity = Vector2.ZERO
		await ticks(6)

		p.set_intent(0, false, true)
		var max_reach := 0.0
		var hits := 0
		for f in range(90):
			await physics_frame
			if f in [18, 45]:
				p.set_intent(0, false, true)
			var dist := shoulder.global_position.distance_to(hand.global_position)
			max_reach = maxf(max_reach, dist)
			var sword: MudWeapon = p.weapons.current
			if sword and sword.impact_flash_timer > 0.0:
				hits += 1
			check(hand.position.is_equal_approx(Vector2(0, 12)),
				"[%s F%02d] HandFront bone position strictly preserves rest Vector2(0, 12), got %s" % [facing_str, f, hand.position])
			check(elbow.position.is_equal_approx(Vector2(0, 12)),
				"[%s F%02d] ForearmFront bone position strictly preserves rest Vector2(0, 12)" % [facing_str, f])
			check(dist <= max_anatomical_reach + 0.05,
				"[%s F%02d] Shoulder-to-hand reach %.2f does not exceed max reach %.2f" % [facing_str, f, dist, max_anatomical_reach])

		check(hits >= 3, "[%s] Consecutive combo hits registered (hits=%d)" % [facing_str, hits])
		check(max_reach <= max_anatomical_reach + 0.05,
			"[%s] 3-hit combo maximum reach was %.2f <= %.2f" % [facing_str, max_reach, max_anatomical_reach])

		# 1.2 Walk -> Attack
		p.revive()
		p.weapons.equip(p.weapons.default_weapon)
		p.sync_weapon_animation()
		p.position = Vector2(base_x - test_facing * 30.0, 136)
		p.facing = test_facing
		await ticks(6)
		p.set_intent(test_facing * 0.5, false, false) # walk
		await ticks(10)
		check(p.state in [&"Walk", &"Run"], "[%s] Walk state entered before attack" % facing_str)
		p.set_intent(test_facing * 0.5, false, true) # attack while walking
		for f in range(30):
			await physics_frame
			var dist := shoulder.global_position.distance_to(hand.global_position)
			check(dist <= max_anatomical_reach + 0.05,
				"[%s Walk-Attack F%02d] Reach %.2f within bounds" % [facing_str, f, dist])

		# 1.3 Run -> Attack
		p.revive()
		p.weapons.equip(p.weapons.default_weapon)
		p.sync_weapon_animation()
		p.position = Vector2(base_x - test_facing * 50.0, 136)
		p.facing = test_facing
		await ticks(6)
		p.set_intent(test_facing * 1.0, false, false) # sprint
		await ticks(12)
		check(p.state == &"Run", "[%s] Run state entered before attack" % facing_str)
		p.set_intent(test_facing * 1.0, false, true) # attack while running
		for f in range(30):
			await physics_frame
			var dist := shoulder.global_position.distance_to(hand.global_position)
			check(dist <= max_anatomical_reach + 0.05,
				"[%s Run-Attack F%02d] Reach %.2f within bounds" % [facing_str, f, dist])

		# 1.4 Jump -> Attack
		p.revive()
		p.weapons.equip(p.weapons.default_weapon)
		p.sync_weapon_animation()
		p.position = Vector2(base_x, 136)
		p.facing = test_facing
		await ticks(6)
		p.set_intent(0, true, false) # jump
		await ticks(5)
		check(not p.is_on_floor(), "[%s] Airborne for jump attack" % facing_str)
		p.set_intent(0, false, true) # attack in air
		for f in range(30):
			await physics_frame
			var dist := shoulder.global_position.distance_to(hand.global_position)
			check(dist <= max_anatomical_reach + 0.05,
				"[%s Jump-Attack F%02d] Reach %.2f within bounds" % [facing_str, f, dist])

		# 1.5 Whiff (No-hit attack)
		p.revive()
		p.weapons.equip(p.weapons.default_weapon)
		p.sync_weapon_animation()
		p.position = Vector2(100, 136) # far away from dummy
		p.facing = test_facing
		await ticks(6)
		p.set_intent(0, false, true)
		for f in range(35):
			await physics_frame
			var dist := shoulder.global_position.distance_to(hand.global_position)
			check(dist <= max_anatomical_reach + 0.05,
				"[%s Whiff F%02d] Whiff reach %.2f within bounds" % [facing_str, f, dist])
		check(hand.position.is_equal_approx(Vector2(0, 12)),
			"[%s Whiff] HandFront position cleanly at rest after whiff" % facing_str)

	print("ARM STRETCH REGRESSION RESULT: %d failures" % errors)
	quit()
