extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/footwork_frames")
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1800,10)
	collision.shape = shape
	floor_body.position = Vector2(320,305)
	floor_body.add_child(collision)
	root.add_child(floor_body)
	var actors: Array[MudCharacter] = []
	for i in 3:
		var a := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		a.player_controlled = false
		a.position = Vector2(85+210*i,296)
		a.scale = Vector2(2,2)
		root.add_child(a)
		a.set_physics_process(false)
		actors.append(a)
		var label := Label.new()
		label.position = Vector2(15+i*210,25)
		label.text = "BLADE %d / FOOTWORK" % (i+1)
		label.add_theme_font_size_override("font_size",12)
		root.add_child(label)
	await physics_frame
	await physics_frame
	for a in actors:
		a.velocity = Vector2(0,30)
		a.move_and_slide()
		check(a.is_on_floor(),"Fixture must stand on floor")
	var a := actors[0]
	for pair in [[&"Idle",1.0],[&"Walk",.65],[&"Run",.35],[&"Jump",0.0],[&"Fall",0.0]]:
		a.pose_composer.restore_base()
		a.state = pair[0]
		a.anim_player.play(a.state,0)
		a.start_attack(2)
		a.attack_time = a.attack_duration*.60
		a.pose_composer.evaluate(0)
		check(is_equal_approx(a.pose_composer.lower_body_weight,pair[1]),"Wrong additive state weight")
		var pelvis := a.skeleton.get_node("Pelvis") as Bone2D
		var base: Transform2D = a.pose_composer.base_pose[pelvis]
		var root_base: Transform2D = a.pose_composer.base_pose[a.pose_root]
		check(absf(pelvis.position.x-base.origin.x) < .01,"Pelvis must not own whole-body attack translation")
		check(absf(a.pose_root.position.x-root_base.origin.x-8.0*float(pair[1])) < .01,"PoseRoot push must scale from base locomotion")
		for side in ["Front","Back"]:
			var shin := pelvis.get_node("Thigh%s/Shin%s" % [side,side]) as Bone2D
			var foot := shin.get_node("Foot"+side) as Bone2D
			check(is_equal_approx(shin.position.length(),16) and is_equal_approx(foot.position.length(),16),"Footwork must not stretch bones")
	for frame in 72:
		for i in 3:
			var actor := actors[i]
			actor.pose_composer.restore_base()
			actor.state = &"Idle"
			if frame%36 == 0:
				actor.anim_player.play(&"Idle",0)
				actor.start_attack(i)
			actor.facing = 1 if frame < 36 else -1
			actor.attack_time = minf((frame%36)/30.0,actor.attack_duration)
			if actor.attack_time >= actor.attack_duration: actor.action_state = &"None"
			actor.pose_composer.evaluate(1.0/30.0)
			actor._sync_visual(1.0/30.0)
			var right := actor._hand_front_bone.global_position
			check(actor.weapons.main_hand.global_position.distance_to(right)<.01,"Turning must keep sword on anatomical right hand")
			var left_slot: Marker2D = actor.equipment.slots[&"LeftForearmSlot"]
			check(left_slot.z_index == (-5 if actor.facing > 0 else 5),"Left accessory must swap depth on turn")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/footwork_frames/%03d.png" % frame)
	for actor in actors:
		actor.rig.character = null
		actor.rig.gait = null
		actor.rig = null
		actor.queue_free()
	floor_body.queue_free()
	await process_frame
	print("FOOTWORK/LAYERS RESULT: ",failures," failures")
	quit(1 if failures else 0)
