extends SceneTree
## Captures the redesigned Sprint/Run animation sequence with Godot's actual SDF renderer.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/sprint_frames")
	var stage := Node2D.new()
	root.add_child(stage)
	
	var ground := Line2D.new()
	ground.points = PackedVector2Array([Vector2(0, 240), Vector2(640, 240)])
	ground.width = 1
	ground.default_color = Color("385078")
	stage.add_child(ground)
	
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	actor.position = Vector2(320, 240)
	actor.scale = Vector2(2.5, 2.5)
	stage.add_child(actor)
	actor.set_physics_process(false)
	actor.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.state = &"Run"
	actor.anim_player.play(&"Run", 0.0)
	
	var anim_len := actor.anim_player.current_animation_length
	for i in 8:
		var t := i * anim_len / 8.0
		actor.anim_player.seek(t, true)
		actor._sync_visual(1.0 / 30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/sprint_frames/%02d.png" % i)
	
	print("Successfully captured 8 sprint frames in Godot.")
	
	actor.rig.character = null
	actor.rig = null
	actor.queue_free()
	stage.queue_free()
	await process_frame
	quit()
