extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	var arena_packed := load("res://scenes/test_arena.tscn")
	var arena := arena_packed.instantiate() as Node2D
	root.add_child(arena)
	await process_frame
	await physics_frame
	
	# 1. World & Background Hierarchy
	check(arena.world_node != null, "World hierarchy node exists")
	check(arena.background_node != null and arena.has_station_background(), "Arena background uses res://scenes/levels/stationBG.png")
	
	# 2. Checkpoints & Teleport
	check(arena.checkpoints.size() == 6, "Arena contains exactly 6 dedicated zone checkpoints")
	for i in range(6):
		arena.teleport_to_zone(i)
		check(arena.player.global_position == arena.checkpoints[i], "Zone %d teleport accurately places player at %s" % [i + 1, str(arena.checkpoints[i])])
		check(arena.player.velocity == Vector2.ZERO, "Zone %d teleport clears transient velocity" % (i + 1))
	
	# Return to Zone 1 Baseline
	arena.teleport_to_zone(0)
	await physics_frame
	check(arena.player.is_on_floor(), "Player stands stably on baseline track")
	
	# 3. Item Test Console & Real Modifier Pipeline
	check(arena.item_console != null, "Developer item modifier console is instantiated")
	var p: MudCharacter = arena.player
	var assist: MudMovementAssist = p.movement_assist
	
	# Base stats verification
	check(is_equal_approx(assist.get_effective_coyote_time(), 0.100), "Base Coyote Time is 0.100 s")
	check(is_equal_approx(assist.get_effective_jump_buffer_time(), 0.080), "Base Jump Buffer Time is 0.080 s")
	
	# Toggle Item 1: Wile glance (+0.06s)
	p.obtain_item(arena.COYOTE_ITEMS[0])
	check(p.item_inventory.has(&"base:wile_glance"), "Wile glance item added to inventory")
	check(is_equal_approx(assist.get_effective_coyote_time(), 0.160), "Wile glance extends Coyote Time to 0.160 s")
	
	# Toggle Item 5: Three-eyed pardon (+0.04s Coyote, +0.05s buffer)
	p.obtain_item(arena.COYOTE_ITEMS[4])
	check(is_equal_approx(assist.get_effective_coyote_time(), 0.200), "Wile + Three-Eyed Pardon stack to 0.200 s Coyote Time")
	check(is_equal_approx(assist.get_effective_jump_buffer_time(), 0.130), "Three-Eyed Pardon extends Jump Buffer to 0.130 s")
	
	# Toggle Item 2: Suspended Absurdity (+12% horizontal launch)
	p.obtain_item(arena.COYOTE_ITEMS[1])
	check(is_equal_approx(assist.coyote_horizontal_jump_multiplier, 1.12), "Suspended Absurdity applies +12% horizontal jump multiplier")
	
	# Toggle Item 3: Hermes Winged Boots (+10% vertical launch)
	p.obtain_item(arena.COYOTE_ITEMS[2])
	check(is_equal_approx(assist.coyote_vertical_jump_multiplier, 1.10), "Hermes Winged Boots applies +10% vertical jump multiplier")
	
	# Toggle Item 4: Dear Cruel Gravity (initial 0.06s gravity x 0.65)
	p.obtain_item(arena.COYOTE_ITEMS[3])
	check(is_equal_approx(assist.coyote_initial_gravity_multiplier, 0.65), "Dear Cruel Gravity sets initial gravity multiplier to 0.65")
	check(is_equal_approx(assist.coyote_initial_gravity_duration, 0.06), "Dear Cruel Gravity initial duration is 0.06 s")
	
	# Reset Items
	p.item_inventory.clear()
	check(p.item_inventory.items().size() == 0, "Reset items clears inventory")
	check(is_equal_approx(assist.get_effective_coyote_time(), 0.100), "Coyote Time reverts to base 0.100 s after reset")
	check(is_equal_approx(assist.get_effective_jump_buffer_time(), 0.080), "Jump Buffer reverts to base 0.080 s after reset")
	
	# 4. Combat Laboratory Dummies
	check(is_instance_valid(arena.stationary_dummy), "Stationary dummy exists in combat arena")
	check(is_instance_valid(arena.blocking_dummy), "Blocking dummy exists in combat arena")
	check(is_instance_valid(arena.damage_dummy), "Damage dummy exists in combat arena")
	check(is_instance_valid(arena.knockback_dummy), "Knockback dummy exists in combat arena")
	check(is_instance_valid(arena.ledge_dummy), "Ledge combat dummy exists in combat arena")
	
	# Test hit on stationary dummy
	var initial_hits: int = arena.stationary_dummy.hit_count
	var hit := HitEvent.new()
	hit.attacker = p
	hit.damage = 10.0
	hit.direction = Vector2.RIGHT
	hit.impact_force = 60.0
	arena.stationary_dummy.receive_hit(hit)
	check(arena.stationary_dummy.hit_count == initial_hits + 1, "Stationary dummy records hit counter")
	
	# Test hit on blocking dummy
	var initial_stab: float = arena.blocking_dummy.stability
	arena.blocking_dummy.receive_hit(hit)
	check(arena.blocking_dummy.stability < initial_stab, "Blocking dummy absorbs hit and takes poise damage")
	
	# Test hit on knockback dummy
	var initial_kx: float = arena.knockback_dummy.global_position.x
	arena.knockback_dummy.receive_hit(hit)
	check(arena.knockback_dummy.velocity.x > 50.0, "Knockback dummy receives horizontal impulse velocity")
	
	# 5. Developer Knockback on Player
	arena.teleport_to_zone(5) # Combat Zone
	await physics_frame
	arena.apply_developer_knockback(90.0, false)
	check(p.reaction_state in [&"LightHit", &"HeavyHit", &"AirHit"], "Developer knockback activates player hit reaction")
	check(p.velocity.x > 30.0, "Developer knockback applies physical impulse to player")
	
	# 6. Wall Mechanics Tower
	arena.player.player_controlled = false
	var tower_wall := arena.get_node_or_null("World/GameplayWorld/Platforms/WallTowerRight") as StaticBody2D
	check(tower_wall != null, "Wall tower exposes its climbable fixture")
	if tower_wall != null:
		arena.player.position = tower_wall.global_position + Vector2(25.0, 62.0)
		arena.player.velocity = Vector2(-70.0, 25.0)
		arena.player.set_intent(-1.0)
	for tick in 20:
		await physics_frame
		if arena.player.is_wall_attached(): break
	check(arena.player.is_wall_attached(), "Wall tower geometry supports WallHang/WallSlide mechanics")
	
	# 7. Respawn System preserves inventory
	p.obtain_item(arena.COYOTE_ITEMS[0])
	p.position = Vector2(500.0, arena.TEST_KILL_Y + 50.0) # Below kill threshold
	await process_frame
	await process_frame
	check(p.item_inventory.has(&"base:wile_glance"), "Respawn preserves equipped debug items")
	check(p.global_position.y < arena.TEST_KILL_Y, "Respawn resets player above kill boundary")
	
	# Clean up
	for character in [arena.player, arena.scoring_enemy] + arena.crowd + arena.real_enemies:
		if is_instance_valid(character) and character is MudCharacter and character.rig:
			character.rig.character = null
			character.rig.gait = null
			character.rig = null
	arena.queue_free()
	await process_frame
	
	print("MECHANICS LAB TEST RESULT: ", failures, " failures")
	quit(1 if failures else 0)
