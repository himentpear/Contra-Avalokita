extends SceneTree

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func run() -> void:
	var startup := StartupConfig.new()
	check(startup.initial_scene == "res://scenes/test_arena.tscn", "StartupConfig uses the one formal test arena")
	var arena := preload("res://scenes/test_arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await physics_frame

	check(arena.player is MudCharacter and arena.player.player_controlled, "Formal arena owns the controllable player")
	check(arena.background_node.get_child_count() == 1 and arena.background_node.get_child(0) is Polygon2D, "Arena background is one solid-color field")
	check(is_equal_approx(arena.camera.position.y, 0.0), "Camera framing is centered at Y=0")
	check(is_instance_valid(arena.dummy) and arena.dummy.has_method("receive_hit"), "Formal arena contains the persistent training dummy")
	check(arena.item_pickups.size() == 5, "Formal arena contains all five item acquisition stations")
	check(get_nodes_in_group(&"climbable_surface").size() >= 3, "Formal arena contains the climbable wall mechanics surfaces")
	arena.player.player_controlled = false
	arena.player.position = Vector2(3395.0, 92.0)
	arena.player.velocity = Vector2(70.0, 25.0)
	arena.player.set_intent(1.0)
	for tick in 20:
		await physics_frame
		if arena.player.is_wall_attached(): break
	check(arena.player.is_wall_attached(), "Integrated wall geometry supports the real WallHang pipeline")
	arena.player.revive()
	arena.player.player_controlled = true
	arena.player.position = Vector2(400.0, 158.0)
	arena.player.velocity = Vector2.ZERO
	await physics_frame

	var before: float = arena.player.get_effective_coyote_time()
	var pickup: Node = arena.item_pickups[0]
	arena.player.position = Vector2(pickup.position.x, 136.0)
	for tick in 3: await physics_frame
	check(pickup.consumed and arena.player.item_inventory.has(&"base:wile_glance"), "Touching a station grants its real content item")
	check(is_equal_approx(arena.player.get_effective_coyote_time(), before+0.06), "Obtained item immediately changes effective movement stats")
	arena.player.position = Vector2(300.0, 136.0)
	arena.player.velocity = Vector2.ZERO

	var enemy: MudCharacter = arena.spawn_real_enemy()
	await physics_frame
	check(enemy.is_in_group(&"training_enemy") and enemy.get_node_or_null("EnemyController") != null, "F3 factory creates a real AI MudCharacter enemy")
	check(enemy.score_profile != null and enemy.get_node_or_null("Hurtbox") is Area2D and enemy.is_armed(), "Real enemy uses score, hurtbox and weapon pipelines")
	var start_x := enemy.position.x
	for tick in 20: await physics_frame
	check(enemy.position.x < start_x, "Spawned enemy actively approaches the player")

	var hit := HitEvent.new()
	hit.attacker = arena.player
	hit.damage = 1000.0
	hit.direction = Vector2.RIGHT
	enemy.receive_hit(hit)
	check(enemy.state == &"Dead", "Spawned enemy uses the real damage and death lifecycle")

	for character in [arena.player, arena.scoring_enemy]+arena.crowd+arena.real_enemies:
		if is_instance_valid(character) and character is MudCharacter and character.rig:
			character.rig.character = null
			character.rig.gait = null
			character.rig = null
	arena.queue_free()
	await process_frame
	print("UNIFIED TEST ARENA RESULT: ", failures, " failures")
	quit(1 if failures else 0)
