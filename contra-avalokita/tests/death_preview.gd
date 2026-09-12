extends SceneTree
## Renders the reference-driven death key poses and SDF particle hand-off.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var stage := Node2D.new()
	root.add_child(stage)

	var backdrop := ColorRect.new()
	backdrop.size = Vector2(640, 360)
	backdrop.color = Color("101d24")
	stage.add_child(backdrop)

	var title := Label.new()
	title.text = "DEATH / SDF ASCENSION"
	title.position = Vector2(20, 18)
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color("d1d9b7")
	stage.add_child(title)

	var samples := [
		{"time": 0.13, "label": "IMPACT"},
		{"time": 0.40, "label": "SUPPORT LOSS"},
		{"time": 0.72, "label": "FALL"},
		{"time": 1.10, "label": "ASCEND"},
	]
	for i in samples.size():
		var x := 86.0 + i * 156.0
		var ground := ColorRect.new()
		ground.position = Vector2(x - 60.0, 284.0)
		ground.size = Vector2(120, 2)
		ground.color = Color("66734d")
		stage.add_child(ground)

		var label := Label.new()
		label.text = samples[i].label
		label.position = Vector2(x - 54.0, 305.0)
		label.size = Vector2(108, 22)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.modulate = Color("aabd7d")
		stage.add_child(label)

		var holder := Node2D.new()
		holder.position = Vector2(x, 284)
		holder.scale = Vector2(2.15, 2.15)
		stage.add_child(holder)
		var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		actor.player_controlled = false
		holder.add_child(actor)
		actor.set_physics_process(false)
		actor.weapons.equip(null)
		actor.die()
		var simulated := 0.0
		while simulated < samples[i].time:
			var step := minf(1.0 / 60.0, samples[i].time - simulated)
			actor.death_controller.update(step)
			if actor.death_ascension.active:
				actor.death_ascension._process(step)
			simulated += step
		actor._sync_visual(0.0)

	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/death_reference_rework.png")
	print("Captured death_reference_rework.png")
	quit()
