extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func caption(stage: Node, text: String, pos: Vector2, size: int, col: Color = Color("d1d9b7")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.modulate = col
	stage.add_child(label)
	return label

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/block_frames")
	var stage := Node2D.new()
	root.add_child(stage)
	
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(640, 360)
	backdrop.color = Color("0d171c")
	stage.add_child(backdrop)

	caption(stage, "COMBAT BLOCK & GUARD SYSTEM (格挡防御机制)", Vector2(24, 14), 16, Color("e0e7cc"))
	caption(stage, "PRESS L TO GUARD  |  ARMED: BRACED SWORD (架住, 倾斜7°)  |  UNARMED: HELMET SHELL (缩住, 高位抱架)", Vector2(24, 34), 9, Color("81947e"))

	var ground := Line2D.new()
	ground.points = PackedVector2Array([Vector2(0, 270), Vector2(640, 270)])
	ground.width = 1
	ground.default_color = Color("385078")
	stage.add_child(ground)

	# Column 1: SWORD BRACED GUARD (架住)
	var col1_title := caption(stage, "SWORD GUARD (架住: 剑微倾7° + 顶住)", Vector2(30, 56), 12, Color("c1d18b"))
	var col1_sub := caption(stage, "Tilted Blade | Rear Leg Braced | Torso Back 3° | Feet Anchored", Vector2(30, 74), 9, Color("829582"))
	var col1_telemetry := caption(stage, "STATE: IDLE READY", Vector2(30, 92), 10, Color("aabd7d"))

	# Column 2: UNARMED HELMET GUARD (缩住)
	var col2_title := caption(stage, "UNARMED GUARD (缩住: 抱架 + 楔形)", Vector2(350, 56), 12, Color("ffd467"))
	var col2_sub := caption(stage, "Helmet Shell | Chin Tucked | Torso Lean 5° | Deep Crouch", Vector2(350, 74), 9, Color("829582"))
	var col2_telemetry := caption(stage, "STATE: IDLE READY", Vector2(350, 92), 10, Color("aabd7d"))

	# Actors for Column 1
	var sword_defender := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	sword_defender.player_controlled = false
	sword_defender.position = Vector2(170, 270)
	sword_defender.scale = Vector2(2.0, 2.0)
	stage.add_child(sword_defender)
	sword_defender.set_physics_process(false)
	sword_defender.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	sword_defender.equipment.toggle()
	sword_defender.anim_player.play(&"Idle", 0.0)

	var sword_attacker := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	sword_attacker.player_controlled = false
	sword_attacker.position = Vector2(275, 270)
	sword_attacker.scale = Vector2(2.0, 2.0)
	sword_attacker.facing = -1.0
	stage.add_child(sword_attacker)
	sword_attacker.set_physics_process(false)
	sword_attacker.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	sword_attacker.equipment.toggle()
	sword_attacker.body_renderer.mud_color = Color("87704b")
	sword_attacker.anim_player.play(&"Idle", 0.0)

	# Actors for Column 2
	var unarm_defender := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	unarm_defender.player_controlled = false
	unarm_defender.position = Vector2(470, 270)
	unarm_defender.scale = Vector2(2.0, 2.0)
	stage.add_child(unarm_defender)
	unarm_defender.set_physics_process(false)
	unarm_defender.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	unarm_defender.weapons.equip(null)
	unarm_defender.sync_weapon_animation()
	unarm_defender.anim_player.play(&"Idle_Unarmed", 0.0)

	var unarm_attacker := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	unarm_attacker.player_controlled = false
	unarm_attacker.position = Vector2(575, 270)
	unarm_attacker.scale = Vector2(2.0, 2.0)
	unarm_attacker.facing = -1.0
	stage.add_child(unarm_attacker)
	unarm_attacker.set_physics_process(false)
	unarm_attacker.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	unarm_attacker.weapons.equip(null)
	unarm_attacker.sync_weapon_animation()
	unarm_attacker.body_renderer.mud_color = Color("725539")
	unarm_attacker.anim_player.play(&"Idle_Unarmed", 0.0)

	# 90 frames total (30 FPS = 3.0s)
	for frame in 90:
		var delta := 1.0 / 30.0

		# Cycle 1: Enter Block at frame 10
		if frame >= 10 and frame < 50:
			sword_defender.set_intent(0.0, false, false, true)
			unarm_defender.set_intent(0.0, false, false, true)
		elif frame >= 50 and frame < 85:
			# Cycle 2: Guard Walk (backstep / advance while blocking)
			sword_defender.set_intent(-0.6, false, false, true)
			unarm_defender.set_intent(-0.6, false, false, true)
		else:
			sword_defender.set_intent(0.0, false, false, false)
			unarm_defender.set_intent(0.0, false, false, false)

		# Attackers strike at frame 22
		if frame == 16:
			sword_attacker.start_attack(0)
			unarm_attacker.start_attack(1) # Cross
		if frame == 24:
			# Sword clash
			var hit1 := HitEvent.new(24.0, Vector2.LEFT, sword_defender.global_position + Vector2(10, -25), 100.0, 30.0, &"HeavyHit", &"blade")
			sword_defender.receive_hit(hit1)
			
			# Punch clash
			var hit2 := HitEvent.new(18.0, Vector2.LEFT, unarm_defender.global_position + Vector2(8, -32), 80.0, 20.0, &"MediumHit", &"unarmed", &"HEAD")
			unarm_defender.receive_hit(hit2)

		# Advance characters
		for c in [sword_defender, sword_attacker, unarm_defender, unarm_attacker]:
			if c.is_attacking():
				c.advance_attack(delta)
			if c.has_reaction():
				c.reaction_time += delta
				if c.reaction_time >= c.reaction_duration:
					c.reaction_state = &"None"
			c.pose_composer.evaluate(delta)
			c._sync_visual(delta)

		# Column 1 Telemetry
		if frame == 24 or frame == 25:
			col1_telemetry.text = "BLOCK HIT! 1f HIT STOP | CLASH SPARK"
			col1_telemetry.modulate = Color("ffffff")
		elif sword_defender.reaction_state == &"BlockHit":
			col1_telemetry.text = "GUARD HIT! SHOCKWAVE: 剑→手→胸→髋"
			col1_telemetry.modulate = Color("ff9282")
		elif frame >= 50 and frame < 85:
			col1_telemetry.text = "GUARD WALK: BACKSTEP (SWORD READY)"
			col1_telemetry.modulate = Color("ffd467")
		elif sword_defender.is_blocking():
			col1_telemetry.text = "ACTION: ARMED GUARD (架住: 剑前倾7°)"
			col1_telemetry.modulate = Color("c1d18b")
		else:
			col1_telemetry.text = "STATE: IDLE READY"
			col1_telemetry.modulate = Color("829582")

		# Column 2 Telemetry
		if frame == 24 or frame == 25:
			col2_telemetry.text = "BLOCK HIT! 1f PIN | MUD SPLATTER"
			col2_telemetry.modulate = Color("ffffff")
		elif unarm_defender.reaction_state == &"BlockHit":
			col2_telemetry.text = "GUARD HIT! FOREARMS ABSORB MOMENTUM"
			col2_telemetry.modulate = Color("ff9282")
		elif frame >= 50 and frame < 85:
			col2_telemetry.text = "GUARD WALK: HELMET SHELL IN STRIDE"
			col2_telemetry.modulate = Color("ffd467")
		elif unarm_defender.is_blocking():
			col2_telemetry.text = "ACTION: UNARMED GUARD (缩住: 抱架)"
			col2_telemetry.modulate = Color("ffd467")
		else:
			col2_telemetry.text = "STATE: IDLE READY"
			col2_telemetry.modulate = Color("829582")

		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/block_frames/%03d.png" % frame)

	# Cleanup
	for c in [sword_defender, sword_attacker, unarm_defender, unarm_attacker]:
		if c.rig:
			c.rig.character = null
			c.rig.gait = null
			c.rig = null
		c.queue_free()
	await process_frame
	quit()
