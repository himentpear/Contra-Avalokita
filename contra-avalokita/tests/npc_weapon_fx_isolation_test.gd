extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena := preload("res://scenes/test_arena.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	var player: MudCharacter = arena.player
	var npc: MudCharacter = arena.npc_attack_test
	var player_sprite := player.weapons.current.get_node("Sprite2D") as Sprite2D
	var npc_sprite := npc.weapons.current.get_node("Sprite2D") as Sprite2D
	var player_mat := player_sprite.material as ShaderMaterial
	var npc_mat := npc_sprite.material as ShaderMaterial
	check(player_mat != npc_mat, "Player and NPC swords have separate shader materials")
	npc_mat.set_shader_parameter("hit_flash", 0.12)
	player_mat.set_shader_parameter("hit_flash", 0.83)
	check(is_equal_approx(npc_mat.get_shader_parameter("hit_flash"), 0.12), "Player sword flash cannot change NPC sword")
	var second_npc: MudCharacter = arena.spawn_real_enemy()
	var second_mat := second_npc.weapons.current.get_node("Sprite2D").material as ShaderMaterial
	check(second_mat != npc_mat and second_mat != player_mat, "Additional NPC sword also has a unique material")
	var third_npc: MudCharacter = arena.spawn_real_enemy()
	check(absf(third_npc.global_position.x - second_npc.global_position.x) >= 56.0, "Successive NPC spawns do not overlap")
	for character in [player, npc, second_npc, third_npc]:
		if is_instance_valid(character) and character.rig:
			character.rig.character = null
			character.rig.gait = null
			character.rig = null
	arena.queue_free()
	await process_frame
	quit(1 if failures else 0)
