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
	DirAccess.make_dir_recursive_absolute("res://artifacts/impact_frames")
	var stage := Node2D.new()
	root.add_child(stage)
	
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(640, 360)
	backdrop.color = Color("0d171c")
	stage.add_child(backdrop)

	caption(stage, "COMBAT IMPACT DYNAMICS (打击感微构系统)", Vector2(24, 14), 16, Color("e0e7cc"))
	caption(stage, "1-FRAME HIT STOP  |  PUSH-FIRST KINEMATICS  |  SDF VOLUMETRIC BULGE  |  ATTACKER RESISTANCE & DRAG", Vector2(24, 34), 9, Color("81947e"))

	var ground := Line2D.new()
	ground.points = PackedVector2Array([Vector2(0, 270), Vector2(640, 270)])
	ground.width = 1
	ground.default_color = Color("385078")
	stage.add_child(ground)

	# Column 1: SWORD SLASH (Heavy Impact)
	var col1_title := caption(stage, "SWORD HEAVY SLASH (刀剑重击)", Vector2(50, 56), 13, Color("c1d18b"))
	var col1_sub := caption(stage, "Hit Stop 2f | Star Flash | Target Push +3.5px | SDF Bulge +2.0px", Vector2(50, 74), 9, Color("829582"))
	var col1_telemetry := caption(stage, "STATE: WINDUP", Vector2(50, 92), 11, Color("aabd7d"))

	# Column 2: UNARMED CROSS (Medium Impact)
	var col2_title := caption(stage, "BOXING CROSS (拳击中击)", Vector2(360, 56), 13, Color("ffd467"))
	var col2_sub := caption(stage, "Hit Stop 1f | Linear Push +2.2px | Attacker Drag 35% | Torso Lag", Vector2(360, 74), 9, Color("829582"))
	var col2_telemetry := caption(stage, "STATE: WINDUP", Vector2(360, 92), 11, Color("aabd7d"))

	# Camera Shake container for stage content
	var shake_node := Node2D.new()
	stage.add_child(shake_node)

	# Setup Actor 1 (Sword Attacker) & Target 1 (Mud Dummy)
	var sword_attacker := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	sword_attacker.player_controlled = false
	sword_attacker.position = Vector2(95, 270)
	sword_attacker.scale = Vector2(2.0, 2.0)
	shake_node.add_child(sword_attacker)
	sword_attacker.set_physics_process(false)
	sword_attacker.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	sword_attacker.equipment.toggle()
	sword_attacker.anim_player.play(&"Idle", 0.0)

	var sword_target := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	sword_target.player_controlled = false
	sword_target.position = Vector2(215, 270)
	sword_target.scale = Vector2(2.0, 2.0)
	sword_target.facing = -1.0
	shake_node.add_child(sword_target)
	sword_target.set_physics_process(false)
	sword_target.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	sword_target.equipment.toggle()
	sword_target.weapons.equip(null)
	sword_target.body_renderer.mud_color = Color("87704b")
	sword_target.anim_player.play(&"Idle_Unarmed", 0.0)

	# Setup Actor 2 (Boxing Attacker) & Target 2 (Mud Dummy)
	var punch_attacker := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	punch_attacker.player_controlled = false
	punch_attacker.position = Vector2(400, 270)
	punch_attacker.scale = Vector2(2.0, 2.0)
	shake_node.add_child(punch_attacker)
	punch_attacker.set_physics_process(false)
	punch_attacker.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	punch_attacker.weapons.equip(null)
	punch_attacker.sync_weapon_animation()
	punch_attacker.anim_player.play(&"Idle_Unarmed", 0.0)

	var punch_target := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	punch_target.player_controlled = false
	punch_target.position = Vector2(520, 270)
	punch_target.scale = Vector2(2.0, 2.0)
	punch_target.facing = -1.0
	shake_node.add_child(punch_target)
	punch_target.set_physics_process(false)
	punch_target.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	punch_target.equipment.toggle()
	punch_target.weapons.equip(null)
	punch_target.body_renderer.mud_color = Color("725539")
	punch_target.anim_player.play(&"Idle_Unarmed", 0.0)

	var shake_timer := 0.0
	var shake_amp := 0.0
	var shake_dir := Vector2.RIGHT

	# 90 frames total (30 FPS = 3.0s), two clean 45-frame cycles
	for frame in 90:
		var delta := 1.0 / 30.0
		var cycle_frame := frame % 45

		# Camera shake disabled
		shake_node.position = Vector2.ZERO

		# --- Column 1: Sword Slash Simulation ---
		if cycle_frame == 5:
			sword_attacker.start_attack(0)
		
		# Contact hit at cycle_frame 14
		if cycle_frame == 14:
			var event := HitEvent.new(28.0, Vector2.RIGHT, sword_target.global_position + Vector2(0, -32), 140.0, 45.0, &"HeavyHit", &"blade", &"UPPER_TORSO")
			event.impact_strength = 0.90
			event.hit_stop_duration = 0.066
			event.hit_stop_frames = 2
			event.target_push_distance = 3.5
			event.attacker_drag_ratio = 0.50
			event.camera_shake_strength = 3.0

			# Target receives hit
			sword_target.receive_hit(event)
			
			# Attacker hit stop & drag & resistance pulse
			sword_attacker.hit_stop_ticks = event.hit_stop_frames
			sword_attacker.hit_stop_duration = event.hit_stop_duration
			sword_attacker.hit_drag_timer = 0.12
			sword_attacker.hit_drag_ratio = event.attacker_drag_ratio
			sword_attacker.impact_accent_offset = Vector2(-sword_attacker.facing * 1.2, 0.0)

			# Trigger weapon impact flash
			if sword_attacker.weapons.current:
				sword_attacker.weapons.current.impact_flash_point = event.impact_point
				sword_attacker.weapons.current.impact_flash_timer = event.hit_stop_duration + 0.033
				sword_attacker.weapons.current.queue_redraw()

			# Camera shake disabled

		if sword_attacker.is_attacking():
			sword_attacker.advance_attack(delta)
		sword_attacker.pose_composer.evaluate(delta)
		sword_attacker._sync_visual(delta)

		if sword_target.has_reaction():
			sword_target.reaction_time += delta
			if sword_target.reaction_time >= sword_target.reaction_duration:
				sword_target.reaction_state = &"None"
		sword_target.pose_composer.evaluate(delta)
		sword_target._sync_visual(delta)

		# Column 1 Telemetry
		if cycle_frame == 14 or cycle_frame == 15:
			col1_telemetry.text = "HIT STOP: 2-FRAME PIN | STAR FLASH | SDF BULGE +2.0px"
			col1_telemetry.modulate = Color("ffffff")
		elif sword_attacker.hit_drag_timer > 0.0:
			col1_telemetry.text = "ATTACKER DRAG (50% SLOWDOWN) | TARGET PUSH-FIRST +3.5px"
			col1_telemetry.modulate = Color("ff9282")
		elif sword_target.has_reaction():
			col1_telemetry.text = "RECOIL & ROTATIONAL STRAIN (INERTIA COLLAPSE)"
			col1_telemetry.modulate = Color("ffd467")
		elif sword_attacker.is_attacking():
			col1_telemetry.text = "SWORD FOLLOW-THROUGH -> RECOVERY"
			col1_telemetry.modulate = Color("aabd7d")
		else:
			col1_telemetry.text = "STATE: IDLE / READY"
			col1_telemetry.modulate = Color("829582")

		# --- Column 2: Punch Cross Simulation ---
		if cycle_frame == 7:
			punch_attacker.start_attack(1) # Cross
		
		# Contact hit at cycle_frame 15
		if cycle_frame == 15:
			var event2 := HitEvent.new(16.0, Vector2.RIGHT, punch_target.global_position + Vector2(0, -30), 80.0, 25.0, &"MediumHit", &"unarmed", &"MID_TORSO")
			event2.impact_strength = 0.65
			event2.hit_stop_duration = 0.033
			event2.hit_stop_frames = 1
			event2.target_push_distance = 2.2
			event2.attacker_drag_ratio = 0.35
			event2.camera_shake_strength = 2.0

			punch_target.receive_hit(event2)

			punch_attacker.hit_stop_ticks = event2.hit_stop_frames
			punch_attacker.hit_stop_duration = event2.hit_stop_duration
			punch_attacker.hit_drag_timer = 0.09
			punch_attacker.hit_drag_ratio = event2.attacker_drag_ratio
			punch_attacker.impact_accent_offset = Vector2(-punch_attacker.facing * 0.8, 0.0)

		if punch_attacker.is_attacking():
			punch_attacker.advance_attack(delta)
		punch_attacker.pose_composer.evaluate(delta)
		punch_attacker._sync_visual(delta)

		if punch_target.has_reaction():
			punch_target.reaction_time += delta
			if punch_target.reaction_time >= punch_target.reaction_duration:
				punch_target.reaction_state = &"None"
		punch_target.pose_composer.evaluate(delta)
		punch_target._sync_visual(delta)

		# Column 2 Telemetry
		if cycle_frame == 15:
			col2_telemetry.text = "HIT STOP: 1-FRAME PIN | SDF DENT & OPPOSITE BULGE"
			col2_telemetry.modulate = Color("ffffff")
		elif punch_attacker.hit_drag_timer > 0.0:
			col2_telemetry.text = "ATTACKER DRAG (35% SLOWDOWN) | TARGET PUSH +2.2px"
			col2_telemetry.modulate = Color("ff9282")
		elif punch_target.has_reaction():
			col2_telemetry.text = "MEDIUM RECOIL | TORSO COMPRESSION DAMPENING"
			col2_telemetry.modulate = Color("ffd467")
		elif punch_attacker.is_attacking():
			punch_attacker.advance_attack(delta)
			col2_telemetry.text = "FIST RETRACTION -> CHIN GUARD"
			col2_telemetry.modulate = Color("aabd7d")
		else:
			col2_telemetry.text = "STATE: UNARMED GUARD"
			col2_telemetry.modulate = Color("829582")

		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/impact_frames/%03d.png" % frame)

	# Cleanup
	for c in [sword_attacker, sword_target, punch_attacker, punch_target]:
		if c.rig:
			c.rig.character = null
			c.rig.gait = null
			c.rig = null
		c.queue_free()
	await process_frame
	quit()
