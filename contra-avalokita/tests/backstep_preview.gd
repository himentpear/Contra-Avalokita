extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/backstep_frames")
	var stage := Node2D.new()
	root.add_child(stage)
	
	var ground := Line2D.new()
	ground.points = PackedVector2Array([Vector2(0, 240), Vector2(640, 240)])
	ground.width = 1
	ground.default_color = Color("385078")
	stage.add_child(ground)
	
	# 3 actors:
	# 0: Forward Attack (facing 1, moving 1 -> Run legs) at x=130
	# 1: Backstep Attack Armed (facing 1, moving -1 -> Backstep legs) at x=320
	# 2: Backstep Attack Unarmed (facing 1, moving -1 -> Backstep_Unarmed legs) at x=510
	var actors: Array[MudCharacter] = []
	var labels = ["FORWARD ATTACK\n(Run Legs)", "RETREAT ATTACK\n(Backstep Legs)", "UNARMED RETREAT\n(Backstep_Unarmed)"]
	
	for i in 3:
		var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		actor.player_controlled = false
		actor.position = Vector2(130 + i * 190, 240)
		actor.scale = Vector2(2.2, 2.2)
		stage.add_child(actor)
		actor.set_physics_process(false)
		actor.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if i == 2:
			actor.weapons.equip(null)
			actor.sync_weapon_animation()
		actors.append(actor)
		
		var lbl := Label.new()
		lbl.text = labels[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(40 + i * 190, 25)
		lbl.size = Vector2(180, 50)
		lbl.add_theme_font_size_override("font_size", 12)
		stage.add_child(lbl)
		
		var sub := Label.new()
		sub.text = "Facing Right ->"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.position = Vector2(40 + i * 190, 68)
		sub.size = Vector2(180, 20)
		sub.add_theme_font_size_override("font_size", 10)
		sub.add_theme_color_override("font_color", Color("8ea0c0"))
		stage.add_child(sub)

	# Set animations
	actors[0].anim_player.play(&"Run", 0.0)
	actors[1].anim_player.play(&"Backstep", 0.0)
	actors[2].anim_player.play(&"Backstep_Unarmed", 0.0)
	
	for a in actors:
		a.start_attack(1)

	# Render 45 frames
	for frame in 45:
		for i in 3:
			var a := actors[i]
			a.pose_composer.restore_base()
			if frame % 40 == 0:
				a.start_attack(1)
			if a.is_attacking():
				a.advance_attack(1.0 / 30.0)
			a.pose_composer.evaluate(1.0 / 30.0)
			a._sync_visual(1.0 / 30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/backstep_frames/%03d.png" % frame)
		
	for a in actors:
		a.rig.character = null
		a.rig.gait = null
		a.rig = null
		a.queue_free()
	await process_frame
	quit()
