extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/blade_frames")
	var actors: Array[MudCharacter] = []
	for i in 3:
		var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		actor.player_controlled = false
		actor.position = Vector2(70+i*210,290)
		actor.scale = Vector2(2,2)
		root.add_child(actor)
		actor.set_physics_process(false)
		actor.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actor.start_attack(i)
		actors.append(actor)
		var label := Label.new()
		label.text = "BLADE / ATTACK %d" % (i+1)
		label.position = Vector2(10+i*210,35)
		root.add_child(label)
	var actor := actors[0]
	for i in 3:
		actor.start_attack(i)
		assert(actor.attack_animation() == "Blade/Attack_%d" % (i+1))
		var window: Vector2 = actor.weapons.current.attack_windows[i]
		actor.weapons.current.update_attack(window.x-.01,true)
		assert(not actor.weapons.current.active)
		actor.weapons.current.update_attack((window.x+window.y)*.5,true)
		assert(actor.weapons.current.active)
		actor.weapons.current.update_attack(window.y+.01,true)
		assert(not actor.weapons.current.active)
	actor.start_attack(0)
	actor.combo_queued = true
	actor.advance_attack(actor.attack_duration)
	assert(actor.combo_stage == 1)
	actor.combo_queued = true
	actor.advance_attack(actor.attack_duration)
	assert(actor.combo_stage == 2)
	actor.combo_queued = true
	actor.advance_attack(actor.attack_duration)
	assert(actor.state == &"Idle")
	actor.start_attack(0)
	actor.advance_attack(actor.attack_duration)
	assert(actor.state == &"Idle", "Single press must not auto-combo")
	print("PASS: Blade category, three stages, input queue, stop after finisher, hit windows")
	for facing in [1.0,-1.0]:
		actor.facing = facing
		actor.start_attack(1)
		actor.anim_player.play(&"Idle",0.0)
		var tips: Array[Vector2] = []
		for t in [.16,.25]:
			actor.pose_composer.restore_base()
			actor.attack_time = t
			actor.pose_composer.evaluate(0.0)
			actor._sync_visual(0.0)
			tips.append(actor.weapons.current.get_node("TrailOrigin").global_position)
			var center := actor.visual.to_local(actor.weapons.current.hitbox.global_position)
			assert(center.distance_to(actor.weapons.current.horizontal_hitbox_offset) < .01)
		var travel := tips[1]-tips[0]
		assert(travel.x*facing > 40 and absf(travel.y) < 10,"Attack 2 must cut horizontally in either facing direction")
	actor.facing = 1
	print("PASS: horizontal tip travel and stable mirrored hitbox")
	for i in 3:
		actors[i].start_attack(i)
		actors[i].anim_player.play(&"Idle",0.0)
	for frame in 60:
		for i in 3:
			var a := actors[i]
			a.pose_composer.restore_base()
			var t := fmod(frame/30.0,1.0)
			if frame == 30: a.weapons.current.begin_attack(i)
			a.attack_time = minf(t,a.attack_duration)
			a.pose_composer.evaluate(1.0/30.0)
			a._sync_visual(1.0/30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/blade_frames/%03d.png" % frame)
	for a in actors:
		a.rig.character = null
		a.rig.gait = null
		a.rig = null
		a.queue_free()
	await process_frame
	quit()
