extends SceneTree
## Captures continuous Run loop side-by-side: Armed vs Unarmed.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/unarmed_run_frames")
	var stage := Node2D.new()
	root.add_child(stage)
	
	var ground := Line2D.new()
	ground.points = PackedVector2Array([Vector2(0, 240), Vector2(640, 240)])
	ground.width = 1
	ground.default_color = Color("385078")
	stage.add_child(ground)
	
	var actor_armed := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor_armed.player_controlled = false
	actor_armed.position = Vector2(200, 240)
	actor_armed.scale = Vector2(2.5, 2.5)
	stage.add_child(actor_armed)
	actor_armed.set_physics_process(false)
	actor_armed.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor_armed.state = &"Run"
	actor_armed.anim_player.play(&"Run", 0.0)
	
	var actor_unarmed := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor_unarmed.player_controlled = false
	actor_unarmed.position = Vector2(440, 240)
	actor_unarmed.scale = Vector2(2.5, 2.5)
	stage.add_child(actor_unarmed)
	actor_unarmed.set_physics_process(false)
	actor_unarmed.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor_unarmed.weapons.equip(null)
	actor_unarmed.state = &"Run"
	actor_unarmed.anim_player.play(&"Run_Unarmed", 0.0)
	
	var total_frames := 16
	var duration := 0.6
	for i in total_frames:
		var t := i * duration / float(total_frames)
		actor_armed.anim_player.seek(t, true)
		actor_armed._sync_visual(1.0 / 30.0)
		
		actor_unarmed.anim_player.seek(t, true)
		actor_unarmed._sync_visual(1.0 / 30.0)
		
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/unarmed_run_frames/%02d.png" % i)
		
	actor_armed.rig.character = null
	actor_armed.rig = null
	actor_armed.queue_free()
	actor_unarmed.rig.character = null
	actor_unarmed.rig = null
	actor_unarmed.queue_free()
	stage.queue_free()
	await process_frame
	quit()
