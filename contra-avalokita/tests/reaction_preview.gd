extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func caption(stage: Node, text: String, pos: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color("d1d9b7")
	stage.add_child(label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/reaction_frames")
	var stage := Node2D.new()
	root.add_child(stage)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(640, 360)
	backdrop.color = Color("101d24")
	stage.add_child(backdrop)

	caption(stage, "REACTION OVERLAY STUDY", Vector2(24, 18), 20)
	caption(stage, "LIGHT HIT (RUNNING)", Vector2(75, 66), 14)
	caption(stage, "HEAVY HIT (STAGGER)", Vector2(395, 66), 14)
	caption(stage, "Continuous run gait preserved | Additive torso recoil", Vector2(30, 305), 11)
	caption(stage, "Poise broken | Attack interrupted | 3-phase recoil curve", Vector2(350, 305), 11)

	var actors: Array[MudCharacter] = []
	var phase_labels: Array[Label] = []

	for col in 2:
		var line := ColorRect.new()
		line.position = Vector2(24 + col * 320, 287)
		line.size = Vector2(272, 2)
		line.color = Color("66734d")
		stage.add_child(line)

		var holder := Node2D.new()
		holder.position = Vector2(160 + col * 320, 281)
		holder.scale = Vector2(2, 2)
		stage.add_child(holder)

		var actor := load("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		actor.player_controlled = false
		holder.add_child(actor)
		actor.set_physics_process(false)
		actor.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actor.equipment.toggle()
		actor.weapons.equip(null)

		if col == 0:
			actor.state = &"Run"
			actor.anim_player.play(&"Run", 0.0)
		else:
			actor.state = &"Idle"
			actor.anim_player.play(&"Idle", 0.0)

		actors.append(actor)

		var status_text := Label.new()
		status_text.position = Vector2(100 + col * 320, 92)
		status_text.add_theme_font_size_override("font_size", 12)
		status_text.modulate = Color("aabd7d")
		stage.add_child(status_text)
		phase_labels.append(status_text)

	# 120 frames at 30 FPS = 4.0 seconds
	for frame in 120:
		var delta := 1.0 / 30.0

		# Actor 0: Running, hit delivered at frame 30
		var a0 := actors[0]
		a0.rig.pose(delta, &"Run", Vector2(105, 0), 0, 0)
		if frame == 30:
			var light_hit := HitEvent.new(8.0, Vector2.LEFT, Vector2.ZERO, 60.0, 15.0, &"LightHit", &"unarmed", &"UPPER_TORSO")
			a0.receive_hit(light_hit)
		if a0.has_reaction():
			a0.reaction_time += delta
			if a0.reaction_time >= a0.reaction_duration:
				a0.reaction_state = &"None"
		a0.pose_composer.evaluate(0.0)
		a0._sync_visual(delta)

		if a0.has_reaction():
			phase_labels[0].text = "REACTION: LIGHT HIT (RUNNING)"
			phase_labels[0].modulate = Color("ff9282")
		else:
			phase_labels[0].text = "GAIT: " + a0.rig.gait.phase_label().to_upper()
			phase_labels[0].modulate = Color("aabd7d")

		# Actor 1: Attack started at frame 15, heavy hit delivered at frame 28
		var a1 := actors[1]
		if frame == 15:
			a1.start_attack(0)
		if frame >= 15 and a1.is_attacking():
			a1.attack_time += delta
		if frame == 28:
			var heavy_hit := HitEvent.new(25.0, Vector2.LEFT, Vector2.ZERO, 140.0, 50.0, &"HeavyHit", &"blade", &"UPPER_TORSO")
			a1.receive_hit(heavy_hit)
		if a1.has_reaction():
			a1.reaction_time += delta
			if a1.reaction_time >= a1.reaction_duration:
				a1.reaction_state = &"None"
		a1.pose_composer.evaluate(delta)
		a1._sync_visual(delta)

		if a1.has_reaction():
			phase_labels[1].text = "STAGGER: INTERRUPTED (RECOIL)"
			phase_labels[1].modulate = Color("ff5b6e")
		elif a1.is_attacking():
			phase_labels[1].text = "ACTION: PUNCH ATTACK"
			phase_labels[1].modulate = Color("ffd467")
		else:
			phase_labels[1].text = "STATE: IDLE RECOVERED"
			phase_labels[1].modulate = Color("aabd7d")

		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/reaction_frames/%03d.png" % frame)

	quit()
