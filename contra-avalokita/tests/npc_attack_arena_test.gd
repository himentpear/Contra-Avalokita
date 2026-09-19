extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena := preload("res://scenes/test_arena.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	var npc: MudCharacter = arena.npc_attack_test
	var player: MudCharacter = arena.player
	check(is_instance_valid(npc) and npc.get_parent().name == "Enemies", "Combat test NPC is present in the authored arena")
	var controller := npc.get_node_or_null("EnemyController") as TrainingEnemyController
	check(controller != null and controller.actor == npc and controller.target == player, "NPC AI targets the player")
	check(npc.is_armed() and npc.get_node_or_null("Hurtbox") is Area2D, "NPC uses the normal weapon and hurtbox")

	player.player_controlled = false
	player.position = npc.position + Vector2(70.0, 0.0)
	player.velocity = Vector2.ZERO
	player.set_intent(0.0)
	var starting_health := player.health
	var attack_count := [0]
	var draw_count := [0]
	npc.combat_component.attack_started.connect(func(_clip: StringName) -> void: attack_count[0] += 1)
	npc.weapons.carry_mode_changed.connect(func(_previous: int, mode: int) -> void:
		if mode == EquipmentController.CarryMode.HAND:
			draw_count[0] += 1
	)
	for tick in 240:
		await physics_frame
		if player.health < starting_health:
			break
	check(attack_count[0] > 0, "NPC initiates its authored sword attack")
	check(draw_count[0] > 0, "NPC draws its back-carried sword before attacking")
	check(player.health < starting_health, "NPC attack reaches the player's real damage pipeline")
	var enemy_count: int = arena.real_enemies.size()
	Input.action_press(&"spawn_enemy")
	await process_frame
	await process_frame
	Input.action_release(&"spawn_enemy")
	check(arena.real_enemies.size() == enemy_count + 1, "F3 spawns an additional attacking NPC")
	var spawned_npc: MudCharacter = arena.real_enemies.back()
	var expected_spawn := arena._find_grounded_npc_spawn(spawned_npc.global_position.x)
	check(is_equal_approx(spawned_npc.global_position.y, expected_spawn.y), "Spawned NPC uses the terrain height at its spawn point")
	spawned_npc.global_position.y = arena.TEST_KILL_Y + 1.0
	await physics_frame
	check(spawned_npc.state == &"Dead", "NPC falling below the void threshold dies")

	var lethal := HitEvent.new()
	lethal.damage = npc.max_health + 1.0
	lethal.direction = Vector2.RIGHT
	npc.receive_hit(lethal)
	check(npc.state == &"Dead", "Combat test NPC can be defeated")
	Input.action_press(&"reset")
	await process_frame
	await process_frame
	Input.action_release(&"reset")
	check(npc.state != &"Dead" and is_equal_approx(npc.health, npc.max_health), "R restores the NPC attack fixture for another test")
	check(arena.real_enemies.is_empty(), "R clears extra F3 enemies between test rounds")

	for character in [player, npc] + arena.real_enemies:
		if is_instance_valid(character) and character.rig:
			character.rig.character = null
			character.rig.gait = null
			character.rig = null
	arena.queue_free()
	await process_frame
	print("NPC ATTACK ARENA RESULT: ", failures, " failures")
	quit(1 if failures else 0)
