extends SceneTree

const ShelterWallCoverScript = preload("res://scripts/environment/shelter_wall_cover.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)

func run() -> void:
	print("--- Running Shelter Wall Cover Test ---")
	test_standalone_cover()
	test_arena_integration()

	if failures == 0:
		print("=== ALL SHELTER WALL COVER TESTS PASSED ===")
		quit(0)
	else:
		printerr("=== %d SHELTER WALL COVER TESTS FAILED ===" % failures)
		quit(1)

func test_standalone_cover() -> void:
	print("\n-- Testing standalone ShelterWallCover (Tightened to Two Rooms) --")
	var scene: PackedScene = load("res://scenes/environment/shelter_wall_cover.tscn")
	check(scene != null, "shelter_wall_cover.tscn preloads successfully")

	var cover = scene.instantiate()
	check(cover != null, "ShelterWallCover instantiates successfully")

	root.add_child(cover)

	check(cover.left_cover_sprite != null, "left_cover_sprite is assigned")
	check(cover.right_cover_sprite != null, "right_cover_sprite is assigned")
	check(cover.left_trigger_area != null, "left_trigger_area is assigned")
	check(cover.right_trigger_area != null, "right_trigger_area is assigned")

	check(cover.left_cover_sprite.texture.resource_path == "res://assets/shelter/inside.png",
		"left_cover_sprite uses inside.png")
	check(cover.right_cover_sprite.texture.resource_path == "res://assets/shelter/inside.png",
		"right_cover_sprite uses inside.png")
	check(cover.left_cover_sprite.z_index >= 30, "left_cover_sprite z_index is higher than player (got %d)" % cover.left_cover_sprite.z_index)
	check(cover.right_cover_sprite.z_index >= 30, "right_cover_sprite z_index is higher than player (got %d)" % cover.right_cover_sprite.z_index)

	# Initial state: outside with no player -> both opaque
	cover.set_revealed(false, true)
	check(cover.is_left_revealed == false and cover.is_right_revealed == false,
		"Initial state: neither room is revealed")
	check(is_equal_approx(cover.left_cover_sprite.modulate.a, 1.0),
		"Initial left_cover alpha is 1.0 (got %f)" % cover.left_cover_sprite.modulate.a)
	check(is_equal_approx(cover.right_cover_sprite.modulate.a, 1.0),
		"Initial right_cover alpha is 1.0 (got %f)" % cover.right_cover_sprite.modulate.a)

	var dummy_player := CharacterBody2D.new()
	dummy_player.name = "Player"
	dummy_player.add_to_group(&"player_input_entities")
	root.add_child(dummy_player)

	# 1. Player is outside to the left (x = -600) -> neither room revealed
	dummy_player.position = cover.to_global(Vector2(-600, -35))
	cover._process(0.016)
	check(cover.is_left_revealed == false and cover.is_right_revealed == false,
		"Player outside to left: neither room revealed")

	# 2. Player enters LEFT room (x = -278, y = -35) -> ONLY left room reveals
	dummy_player.position = cover.to_global(Vector2(-278, -35))
	cover._process(0.016)
	check(cover.is_left_revealed == true, "Player in left room: is_left_revealed = true")
	check(cover.is_right_revealed == false, "Player in left room: is_right_revealed = false (tightened!)")
	if cover._left_tween and cover._left_tween.is_valid():
		cover._left_tween.custom_step(1.0)
	check(is_equal_approx(cover.left_cover_sprite.modulate.a, 0.0),
		"left_cover fades to 0.0 in left room (got %f)" % cover.left_cover_sprite.modulate.a)
	check(is_equal_approx(cover.right_cover_sprite.modulate.a, 1.0),
		"right_cover stays 1.0 when player is in left room (got %f)" % cover.right_cover_sprite.modulate.a)

	# 3. Player steps out onto the MIDDLE SUSPENSION BRIDGE (x = 0, y = -35) -> BOTH closed!
	dummy_player.position = cover.to_global(Vector2(0, -35))
	cover._process(0.016)
	check(cover.is_left_revealed == false, "Player on bridge: is_left_revealed = false (tightened!)")
	check(cover.is_right_revealed == false, "Player on bridge: is_right_revealed = false (tightened!)")
	if cover._left_tween and cover._left_tween.is_valid():
		cover._left_tween.custom_step(1.0)
	check(is_equal_approx(cover.left_cover_sprite.modulate.a, 1.0),
		"left_cover fades back to 1.0 on bridge (got %f)" % cover.left_cover_sprite.modulate.a)
	check(is_equal_approx(cover.right_cover_sprite.modulate.a, 1.0),
		"right_cover stays 1.0 on bridge (got %f)" % cover.right_cover_sprite.modulate.a)

	# 4. Player enters RIGHT room (x = 280, y = -35) -> ONLY right room reveals
	dummy_player.position = cover.to_global(Vector2(280, -35))
	cover._process(0.016)
	check(cover.is_left_revealed == false, "Player in right room: is_left_revealed = false")
	check(cover.is_right_revealed == true, "Player in right room: is_right_revealed = true")
	if cover._right_tween and cover._right_tween.is_valid():
		cover._right_tween.custom_step(1.0)
	check(is_equal_approx(cover.right_cover_sprite.modulate.a, 0.0),
		"right_cover fades to 0.0 in right room (got %f)" % cover.right_cover_sprite.modulate.a)
	check(is_equal_approx(cover.left_cover_sprite.modulate.a, 1.0),
		"left_cover stays 1.0 when player is in right room (got %f)" % cover.left_cover_sprite.modulate.a)

	# 5. Player exits to outside right (x = 600, y = -35) -> BOTH closed
	dummy_player.position = cover.to_global(Vector2(600, -35))
	cover._process(0.016)
	check(cover.is_right_revealed == false, "Player outside to right: is_right_revealed = false")
	if cover._right_tween and cover._right_tween.is_valid():
		cover._right_tween.custom_step(1.0)
	check(is_equal_approx(cover.right_cover_sprite.modulate.a, 1.0),
		"right_cover fades back to 1.0 outside (got %f)" % cover.right_cover_sprite.modulate.a)

	dummy_player.queue_free()
	cover.queue_free()

func test_arena_integration() -> void:
	print("\n-- Testing test_arena.tscn integration --")
	var arena_scene: PackedScene = load("res://scenes/test_arena.tscn")
	check(arena_scene != null, "test_arena.tscn preloads successfully")

	var arena: Node = arena_scene.instantiate()
	root.add_child(arena)

	var scenery: Node2D = arena.get_node_or_null("World/GameplayWorld/Scenery") as Node2D
	check(scenery != null, "World/GameplayWorld/Scenery exists")

	var im13: Sprite2D = scenery.get_node_or_null("Image(13)") as Sprite2D
	check(im13 != null, "Image(13) exists in Scenery")

	var wall_cover = scenery.get_node_or_null("ShelterWallCover")
	check(wall_cover != null, "ShelterWallCover exists in Scenery")

	if wall_cover and im13:
		check(wall_cover.global_position.is_equal_approx(im13.global_position),
			"ShelterWallCover matches Image(13) position (cover: %s, im13: %s)" % [wall_cover.global_position, im13.global_position])
		check(wall_cover.scale.is_equal_approx(im13.scale),
			"ShelterWallCover matches Image(13) scale (cover: %s, im13: %s)" % [wall_cover.scale, im13.scale])
		check(wall_cover.left_cover_sprite != null and wall_cover.right_cover_sprite != null,
			"ShelterWallCover has both left and right cover sprites")
		check(wall_cover.left_trigger_area != null and wall_cover.right_trigger_area != null,
			"ShelterWallCover has both left and right trigger areas")

	arena.queue_free()
