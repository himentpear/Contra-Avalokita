extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/layered_frames")
	var actors: Array[MudCharacter] = []
	for i in 4:
		var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		actor.player_controlled = false
		actor.position = Vector2(53+i*160,295)
		actor.scale = Vector2(1.8,1.8)
		root.add_child(actor)
		actor.set_physics_process(false)
		actor.state = [&"Idle",&"Walk",&"Run",&"Jump"][i]
		actor.anim_player.play(actor.state,0)
		actors.append(actor)
		var label := Label.new()
		label.text = String(actor.state).to_upper()+" + ATTACK 2"
		label.position = Vector2(8+i*160,30)
		label.add_theme_font_size_override("font_size",11)
		root.add_child(label)
	for frame in 90:
		for i in 4:
			var a := actors[i]
			a.pose_composer.restore_base()
			if i == 3:
				var phase := (frame%30)/30.0
				a.velocity.y = lerpf(-180,180,phase)
				a.transition(&"Jump" if a.velocity.y < 0 else &"Fall")
				a.position.y = 295-sin(phase*PI)*40
			if frame%30 == 4: a.start_attack(1)
			if a.is_attacking(): a.advance_attack(1.0/30.0)
			a.pose_composer.evaluate(1.0/30.0)
			a._sync_visual(1.0/30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/layered_frames/%03d.png" % frame)
	for a in actors:
		a.rig.character = null
		a.rig.gait = null
		a.rig = null
		a.queue_free()
	await process_frame
	quit()
