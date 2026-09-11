extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for animation in [&"Walk", &"Run"]:
		actor.state = animation
		actor.anim_player.play(animation,0.0)
		var flight_samples := 0
		var worst_sole := -100.0
		var max_knee_drive := 0.0
		for frame in 240:
			actor.anim_player.seek(frame/240.0*actor.anim_player.current_animation_length,true)
			actor._sync_visual(0.0)
			var pelvis := actor.body_renderer.point(&"Pelvis")
			var torso := actor.skeleton.get_node("Pelvis/Torso") as Bone2D
			assert(torso.global_position.x > pelvis.x, "Chest must stay ahead of pelvis")
			var min_clearance := 100.0
			for side in ["Front", "Back"]:
				var thigh := actor.skeleton.get_node("Pelvis/Thigh%s" % side) as Bone2D
				max_knee_drive = maxf(max_knee_drive, -rad_to_deg(thigh.global_rotation))
				var foot := actor.skeleton.get_node("Pelvis/Thigh%s/Shin%s/Foot%s" % [side,side,side]) as Bone2D
				var axis := Vector2.RIGHT.rotated(foot.global_rotation)
				var sole := foot.global_position.y + maxf(-axis.y,4.2*axis.y) + 3.25
				worst_sole = maxf(worst_sole,sole)
				min_clearance = minf(min_clearance,-sole)
			if min_clearance > 1.5:
				flight_samples += 1
			var hand := actor.skeleton.get_node("Pelvis/Torso/UpperArmFront/ForearmFront/HandFront") as Bone2D
			assert(actor.weapons.main_hand.global_position.distance_to(hand.global_position) < 0.001)
			assert(absf(angle_difference(actor.weapons.main_hand.global_rotation,hand.global_rotation)) < 0.001)
		if animation == &"Run":
			assert(flight_samples >= 30, "Run needs a readable flight interval")
			assert(max_knee_drive <= 61.0, "Avoid horizontal thighs / high-knee jogging")
		else:
			assert(flight_samples == 0, "Walk must always have a supporting foot")
		assert(worst_sole < 1.0, "Feet must not penetrate ground by a full pixel")
		print(animation, ": flight samples=",flight_samples,"/240; maximum sole y=",worst_sole,"; knee drive=",max_knee_drive)
	# The slot must mirror the authored blade axis with the visual root.
	actor.facing = -1
	actor._sync_visual(0.0)
	var hand := actor.skeleton.get_node("Pelvis/Torso/UpperArmFront/ForearmFront/HandFront") as Bone2D
	assert(actor.weapons.main_hand.global_position.distance_to(hand.global_position) < 0.001)
	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	await process_frame
	print("PASS: actual Walk/Run tracks, contact, flight and sword grip")
	quit()
