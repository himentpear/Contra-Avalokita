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
	DirAccess.make_dir_recursive_absolute("res://artifacts/gait_frames")
	var stage := Node2D.new()
	root.add_child(stage)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(640, 360)
	backdrop.color = Color("101d24")
	stage.add_child(backdrop)
	caption(stage, "MIRE / LOCOMOTION STUDY", Vector2(24, 18), 22)
	caption(stage, "WALK", Vector2(120, 70), 16)
	caption(stage, "RUN", Vector2(445, 70), 16)
	caption(stage, "HEEL > SUPPORT > TOE-OFF", Vector2(43, 308), 12)
	caption(stage, "DRIVE > FLIGHT > RECOVERY", Vector2(358, 308), 12)
	caption(stage, "Opposed shoulders / pelvis  |  delayed elbows / wrists  |  foot IK", Vector2(43, 338), 11)
	var actors: Array[MudCharacter] = []
	var phase_labels: Array[Label] = []
	for col in 2:
		var line := ColorRect.new()
		line.position = Vector2(24 + col * 320, 287)
		line.size = Vector2(272, 2)
		line.color = Color("66734d")
		stage.add_child(line)
		var holder := Node2D.new()
		holder.position = Vector2(148 + col * 320, 281)
		holder.scale = Vector2(2, 2)
		stage.add_child(holder)
		var actor := load("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		actor.player_controlled = false
		holder.add_child(actor)
		actor.set_physics_process(false)
		actor.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var initial_anim: StringName = &"Walk" if col == 0 else &"Run"
		actor.state = initial_anim
		actor.anim_player.play(initial_anim, 0.0)
		actor.equipment.toggle()
		actor.weapons.equip(null)
		actors.append(actor)
		var phase_text := Label.new()
		phase_text.position = Vector2(113 + col * 320, 96)
		phase_text.add_theme_font_size_override("font_size", 12)
		phase_text.modulate = Color("aabd7d")
		stage.add_child(phase_text)
		phase_labels.append(phase_text)
	for frame in 150:
		for col in 2:
			var actor := actors[col]
			actor.rig.pose(1.0 / 30.0, &"Walk" if col == 0 else &"Run", Vector2(45 if col == 0 else 105, 0), 0, 0)
			actor._sync_visual(1.0 / 30.0)
			phase_labels[col].text = actor.rig.gait.phase_label().to_upper()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/gait_frames/%03d.png" % frame)
	quit()
