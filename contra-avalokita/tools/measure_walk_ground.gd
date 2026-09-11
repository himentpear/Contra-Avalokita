extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var a := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	root.add_child(a)
	a.set_physics_process(false)
	a.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	a.anim_player.play(&"Walk",0)
	var keys := []
	for frame in 97:
		var t := frame/96.0*.8
		a.anim_player.seek(t,true)
		var bottom := -1000.0
		for side in ["Front","Back"]:
			var f := a.skeleton.get_node("Pelvis/Thigh%s/Shin%s/Foot%s" % [side,side,side]) as Bone2D
			var angle := f.global_rotation
			var radius := 2.8+.45*clampf(1-absf(angle)*1.6,0,1)
			bottom = maxf(bottom,f.global_position.y+maxf(-sin(angle)+radius,maxf(sin(angle)*2.6+radius,sin(angle)*4.2+maxf(1.8,radius-.35))))
		var pelvis := a.skeleton.get_node("Pelvis") as Bone2D
		keys.append([t,pelvis.position.x,pelvis.position.y-bottom])
	FileAccess.open("res://artifacts/grounded_walk_keys.json",FileAccess.WRITE).store_string(JSON.stringify(keys))
	a.rig.character = null
	a.rig.gait = null
	a.rig = null
	a.queue_free()
	await process_frame
	quit()
