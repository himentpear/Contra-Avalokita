extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func platform(position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	root.add_child(body)
	return body

func run() -> void:
	var floor_body := platform(Vector2(320, 340), Vector2(640, 20))
	var wall_body := platform(Vector2(250, 205), Vector2(20, 270))
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	actor.position = Vector2(190, 165)
	actor.velocity = Vector2(105, 80)
	root.add_child(actor)

	var saw_hang := false
	for frame in 90:
		actor.set_intent(1.0)
		await physics_frame
		if actor.wall_action == &"WallHang":
			saw_hang = true
			break
	check(saw_hang, "Approaching a wall while airborne enters WallHang")
	check(actor.anim_player.current_animation == &"Wall/Hang", "WallHang is driven by the editable Wall/Hang AnimationPlayer clip")
	for frame in 5:
		actor.set_intent(1.0)
		await physics_frame
	check(actor.wall_side > 0.0 and actor.facing > 0.0, "Wall side and facing point toward the contacted wall")
	check(absf(actor.velocity.y) < 1.0, "WallHang arrests vertical velocity")
	check(absf(actor._hand_front_bone.global_position.x - actor.wall_surface_x) < 3.0, "Main hand is constrained to the physical wall plane")
	var front_toe := actor._foot_front_bone.to_global(Vector2(4.2, 0.0))
	check(absf(front_toe.x - actor.wall_surface_x) < 5.0, "Raised foot tip is constrained to the physical wall plane: toe=%.2f wall=%.2f" % [front_toe.x, actor.wall_surface_x])
	check((actor._shin_front_bone.global_position.x - actor._thigh_front_bone.global_position.x) * actor.wall_side < 0.0, "WallHang support knee opens away from the wall")
	check(actor._foot_front_bone.global_position.y < actor._foot_back_bone.global_position.y - 12.0, "WallHang raises the braced knee and leaves an asymmetric lower support: high=%.2f low=%.2f" % [actor._foot_front_bone.global_position.y, actor._foot_back_bone.global_position.y])
	var elbow_inner_angle := 180.0 - float(actor.body_renderer.angles.get("ArmFront", 180.0))
	check(elbow_inner_angle >= 30.0 and elbow_inner_angle <= 50.0, "WallHang main elbow keeps a 30-50 degree inner bend: %.1f" % elbow_inner_angle)

	var saw_slide := false
	for frame in 40:
		actor.set_intent(1.0)
		await physics_frame
		if actor.wall_action == &"WallSlide":
			saw_slide = true
			break
	check(saw_slide, "WallHang transitions into WallSlide after the hold window")
	check(actor.anim_player.current_animation == &"Wall/Slide", "WallSlide is driven by the editable Wall/Slide AnimationPlayer clip")
	check(actor.velocity.y <= actor.wall_slide_speed + 0.1, "WallSlide caps downward velocity")
	var slide_body_y := actor.global_position.y
	var slide_hand_y := actor._hand_front_bone.global_position.y
	for frame in 8:
		actor.set_intent(1.0)
		await physics_frame
	var body_drop := actor.global_position.y - slide_body_y
	var hand_drop := actor._hand_front_bone.global_position.y - slide_hand_y
	check(body_drop > hand_drop + 0.5, "WallSlide body descends relative to its slower hand anchor")
	var slide_hip := actor._thigh_front_bone.global_position
	var slide_knee := actor._shin_front_bone.global_position
	var slide_ankle := actor._foot_front_bone.global_position
	check(slide_knee.y > slide_hip.y + 2.0, "WallSlide knee stays below the hip instead of folding upward")
	check((slide_knee.x - slide_hip.x) * actor.wall_side < 0.0, "WallSlide knee pole opens away from the wall: hip=%.2f knee=%.2f" % [slide_hip.x, slide_knee.x])
	check((slide_ankle.x - slide_knee.x) * actor.wall_side > 0.0, "WallSlide ankle stays wall-side of the knee instead of inverting the leg: knee=%.2f ankle=%.2f" % [slide_knee.x, slide_ankle.x])

	actor.set_intent(1.0, true)
	await physics_frame
	check(actor.wall_action == &"WallPush", "Jump input starts the compressed WallPush anticipation")
	check(actor.anim_player.current_animation == &"Wall/Push", "WallPush is driven by the editable Wall/Push AnimationPlayer clip")
	check(absf(actor.velocity.y) < 1.0, "WallPush holds launch velocity during anticipation")
	check((actor._shin_front_bone.global_position.x - actor._thigh_front_bone.global_position.x) * actor.wall_side < 0.0, "WallPush compression keeps the support knee open away from the wall")
	var saw_release := false
	for frame in 10:
		actor.set_intent(1.0)
		await physics_frame
		if actor.wall_action == &"WallRelease":
			saw_release = true
			break
	check(saw_release, "WallPush transitions into WallRelease after the compression frames")
	check(actor.anim_player.current_animation == &"Wall/Release", "WallRelease is driven by the editable Wall/Release AnimationPlayer clip")
	check(actor.velocity.x < -actor.wall_jump_horizontal_speed * 0.75, "WallJump pushes away from the wall")
	check(actor.velocity.y < -actor.wall_jump_vertical_speed * 0.75, "WallJump launches upward")
	check(actor.wall_regrab_left > 0.0, "WallJump opens a re-grab cooldown")
	check(actor.jump_phase == &"WallRelease", "Wall release exposes its animation phase")
	check((actor._shin_front_bone.global_position.x - actor._thigh_front_bone.global_position.x) * actor.wall_side < 0.0, "WallRelease preserves the outward knee pole before returning to the airborne pose")

	var mirrored := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	mirrored.player_controlled = false
	mirrored.position = Vector2(310, 165)
	mirrored.velocity = Vector2(-105, 80)
	root.add_child(mirrored)
	var saw_left_hang := false
	for frame in 90:
		mirrored.set_intent(-1.0)
		await physics_frame
		if mirrored.wall_action == &"WallHang":
			saw_left_hang = true
			break
	check(saw_left_hang and mirrored.wall_side < 0.0 and mirrored.facing < 0.0, "Wall actions mirror correctly on a left-facing wall")
	check(absf(mirrored._hand_front_bone.global_position.x - mirrored.wall_surface_x) < 3.0, "Mirrored cling keeps the hand on the left wall plane")

	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	mirrored.rig.character = null
	mirrored.rig.gait = null
	mirrored.rig = null
	mirrored.queue_free()
	floor_body.queue_free()
	wall_body.queue_free()
	await process_frame
	print("WALL MOVEMENT RESULT: ", failures, " failures")
	quit(1 if failures else 0)
