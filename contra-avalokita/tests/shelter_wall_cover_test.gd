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
	print("\n-- Testing standalone ShelterWallCover --")
	var scene: PackedScene = load("res://scenes/environment/shelter_wall_cover.tscn")
	check(scene != null, "shelter_wall_cover.tscn preloads successfully")

	var cover = scene.instantiate()
	check(cover != null, "ShelterWallCover instantiates successfully")

	root.add_child(cover)

	check(cover.cover_sprite != null, "cover_sprite is assigned")
	check(cover.cover_sprite.texture != null, "cover_sprite has texture")
	check(cover.cover_sprite.texture.resource_path == "res://assets/shelter/inside.png",
		"cover_sprite uses inside.png (got %s)" % cover.cover_sprite.texture.resource_path)
	check(cover.cover_sprite.light_mask == 4, "cover_sprite light_mask is 4 (scenery)")
	check(cover.cover_sprite.z_index == 1, "cover_sprite z_index is 1 (in front of interior and player)")
	check(cover.trigger_area != null, "trigger_area is assigned")

	# Initial state with no player
	cover.set_revealed(false, true)
	check(cover.is_revealed == false, "Initial state is unrevealed")
	check(is_equal_approx(cover.cover_sprite.modulate.a, 1.0),
		"Initial cover_sprite alpha is 1.0 (got %f)" % cover.cover_sprite.modulate.a)

	# Simulate player approaching within bounds
	var dummy_player := CharacterBody2D.new()
	dummy_player.name = "Player"
	dummy_player.add_to_group(&"player_input_entities")
	dummy_player.position = cover.global_position
	root.add_child(dummy_player)

	cover._process(0.016)
	check(cover.is_revealed == true, "Player inside bounds triggers reveal (is_revealed = true)")
	if cover._tween and cover._tween.is_valid():
		cover._tween.custom_step(1.0)
	check(is_equal_approx(cover.cover_sprite.modulate.a, 0.0),
		"cover_sprite fades to 0.0 when player is near (got %f)" % cover.cover_sprite.modulate.a)

	# Simulate player moving away
	dummy_player.position = cover.global_position + Vector2(2500, 0)
	cover._process(0.016)
	check(cover.is_revealed == false, "Player moving away triggers hide (is_revealed = false)")
	if cover._tween and cover._tween.is_valid():
		cover._tween.custom_step(1.0)
	check(is_equal_approx(cover.cover_sprite.modulate.a, 1.0),
		"cover_sprite fades back to 1.0 when player leaves (got %f)" % cover.cover_sprite.modulate.a)

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
		check(wall_cover.cover_sprite != null and wall_cover.cover_sprite.texture != null,
			"ShelterWallCover has valid cover_sprite with texture")
		check(wall_cover.cover_sprite.texture.resource_path == "res://assets/shelter/inside.png",
			"ShelterWallCover texture is inside.png")

	arena.queue_free()
