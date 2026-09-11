extends SceneTree
## Captures the actual AnimationLibrary, with the equipped sword and renderer.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/reference_frames")
	var stage := Node2D.new()
	root.add_child(stage)
	var actors: Array[MudCharacter] = []
	for column in 2:
		var label := Label.new()
		label.text = "WALK / SWORD" if column == 0 else "RUN / SWORD"
		label.position = Vector2(58 + 320 * column, 28)
		stage.add_child(label)
		var ground := Line2D.new()
		ground.points = PackedVector2Array([Vector2(20+column*320,290),Vector2(300+column*320,290)])
		ground.width = 1
		ground.default_color = Color("67754d")
		stage.add_child(ground)
		var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		actor.player_controlled = false
		actor.position = Vector2(125+column*320,290)
		actor.scale = Vector2(2.5,2.5)
		stage.add_child(actor)
		actor.set_physics_process(false)
		actor.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actor.state = &"Walk" if column == 0 else &"Run"
		actor.anim_player.play(actor.state,0.0)
		actors.append(actor)
	for frame in 72:
		for actor in actors:
			actor.anim_player.seek(fmod(frame/30.0,actor.anim_player.current_animation_length),true)
			actor._sync_visual(1.0/30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/reference_frames/%03d.png" % frame)
	print("Captured 72 actual AnimationPlayer frames with sword.")
	# Break the existing adapter's RefCounted back-reference before fixture teardown.
	for actor in actors:
		actor.rig.character = null
		actor.rig.gait = null
		actor.rig = null
	stage.queue_free()
	await process_frame
	quit()
