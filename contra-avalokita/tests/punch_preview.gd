extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/punch_frames")
	var stage := Node2D.new()
	root.add_child(stage)
	
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(640, 360)
	backdrop.color = Color("101d24")
	stage.add_child(backdrop)
	
	var header := Label.new()
	header.text = "BOXING COMBAT STUDY: KINETIC CHAINS & DUMMY IMPACT"
	header.position = Vector2(24, 16)
	header.add_theme_font_size_override("font_size", 14)
	header.modulate = Color("d1d9b7")
	stage.add_child(header)
	
	var ground := Line2D.new()
	ground.points = PackedVector2Array([Vector2(0, 240), Vector2(640, 240)])
	ground.width = 1
	ground.default_color = Color("385078")
	stage.add_child(ground)
	
	# 3 columns showing the 3 boxing punches at impact peak:
	# Col 1 (x=110): Punch 1 - Lead Jab
	# Col 2 (x=305): Punch 2 - Rear Cross
	# Col 3 (x=500): Punch 3 - Lead Hook
	var actors: Array[MudCharacter] = []
	var dummies: Array[Node2D] = []
	var titles = [
		"STAGE 1: LEAD JAB (0.32s)\nElbow 11.5° | Chin Guard | +3.5px",
		"STAGE 2: REAR CROSS (0.36s)\nElbow 12.6° | Chest 18.3° | +4.5px",
		"STAGE 3: LEAD HOOK (0.42s)\nElbow 83.1° | Torque 20.6° | High Arc"
	]
	
	for i in 3:
		var x_pos := 110.0 + i * 195.0
		var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		actor.player_controlled = false
		actor.position = Vector2(x_pos, 240)
		actor.scale = Vector2(2.1, 2.1)
		stage.add_child(actor)
		actor.set_physics_process(false)
		actor.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actor.weapons.equip(null)
		actor.sync_weapon_animation()
		actor.anim_player.play(&"Idle_Unarmed", 0.0)
		actors.append(actor)
		
		# Training dummy at strike distance
		var dummy = preload("res://scripts/training_dummy.gd").new()
		dummy.position = Vector2(x_pos + 85.0, 240)
		dummy.scale = Vector2(2.1, 2.1)
		stage.add_child(dummy)
		dummies.append(dummy)
		
		var lbl := Label.new()
		lbl.text = titles[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(20 + i * 195, 45)
		lbl.size = Vector2(200, 50)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.modulate = Color("aabd7d")
		stage.add_child(lbl)

	# 54 frames (3 punch cycles of 18 frames) showing all 3 punches hitting dummies
	for frame in 54:
		for i in 3:
			var a := actors[i]
			a.pose_composer.restore_base()
			
			# Cycle punch every 18 frames
			if frame % 18 == 0:
				a.start_attack(i)
			if a.is_attacking():
				a.advance_attack(1.0 / 30.0)
			a.pose_composer.evaluate(1.0 / 30.0)
			a._sync_visual(1.0 / 30.0)
			
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/punch_frames/%03d.png" % frame)
		
	for a in actors:
		if a.rig:
			a.rig.character = null
			a.rig.gait = null
			a.rig = null
		a.queue_free()
	for d in dummies:
		d.queue_free()
	await process_frame
	quit()
