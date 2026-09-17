extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func sole(actor: MudCharacter) -> float:
	var bottom := -1000.0
	for side in ["Front","Back"]:
		var foot := actor.skeleton.get_node("Pelvis/Thigh%s/Shin%s/Foot%s" % [side,side,side]) as Bone2D
		var angle := foot.global_rotation
		var radius := 2.8+.45*clampf(1-absf(angle)*1.6,0,1)
		var y := foot.global_position.y
		bottom = maxf(bottom,maxf(y-sin(angle)+radius,maxf(y+sin(angle)*2.6+radius,y+sin(angle)*4.2+maxf(1.8,radius-.35))))
	return bottom

func run() -> void:
	var a := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	a.player_controlled = false
	root.add_child(a)
	a.set_physics_process(false)
	a.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for animation in [&"Idle", &"Walk"]:
		a.anim_player.play(animation,0)
		var minimum := 1000.0
		var maximum := -1000.0
		for frame in 120:
			a.anim_player.seek(frame/120.0*a.anim_player.current_animation_length,true)
			minimum = minf(minimum,sole(a))
			maximum = maxf(maximum,sole(a))
		print(animation," sole range: ",minimum," .. ",maximum)
		if animation == &"Idle":
			assert(maximum < .05 and minimum > -.05,"Idle must stay on the sole plane")
		else:
			assert(maximum < .05 and maximum > -.05 and minimum > -1.5,"Idle and Walk must share the same sole plane")
	var blend_max := 0.0
	for phase in [0.0,.2,.4,.6]:
		a.anim_player.play(&"Walk",0)
		a.anim_player.seek(phase,true)
		a.anim_player.play(&"Idle",.09)
		for frame in 12:
			a.anim_player.advance(1.0/120.0)
			blend_max = maxf(blend_max,absf(sole(a)))
	print("Walk to Idle blend maximum sole offset: ",blend_max)
	assert(blend_max < 1.0,"Stopping must not change ground height by a full pixel")
	a.rig.character = null
	a.rig.gait = null
	a.rig = null
	a.queue_free()
	await process_frame
	quit()
