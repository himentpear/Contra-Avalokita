extends SceneTree

var failures := 0
var wall: StaticBody2D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func make_wall() -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Vector2(250, 205)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 500)
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return body

func attach_left_wall() -> MudCharacter:
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	actor.position = Vector2(310, 165)
	actor.velocity = Vector2(-105, 80)
	root.add_child(actor)
	for frame in 90:
		actor.set_intent(-1.0)
		await physics_frame
		if actor.is_wall_attached():
			break
	return actor

func free_actor(actor: MudCharacter) -> void:
	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	await process_frame

func run() -> void:
	wall = make_wall()

	var toward := await attach_left_wall()
	toward.set_intent(-1.0, true)
	await physics_frame
	check(toward.wall_action == &"WallPush" and toward.pending_wall_jump_kind == &"Climb", "A: left wall toward + Jump has wall-jump priority")
	await free_actor(toward)

	var away := await attach_left_wall()
	away.set_intent(1.0, true)
	await physics_frame
	check(away.wall_action == &"WallPush" and away.pending_wall_jump_kind == &"Kick", "B: left wall away + Jump remains a legal Wall Kick")
	await free_actor(away)

	var detach := await attach_left_wall()
	detach.set_intent(1.0)
	await physics_frame
	check(detach.is_wall_attached(), "C: one-frame away-input jitter is filtered by detach grace")
	for frame in 8:
		detach.set_intent(1.0)
		await physics_frame
		if not detach.is_wall_attached():
			break
	check(not detach.is_wall_attached(), "C: sustained away input without Jump voluntarily detaches")
	await free_actor(detach)

	var no_double := await attach_left_wall()
	no_double.set_intent(0.0, true)
	await physics_frame
	for frame in 12:
		no_double.set_intent(0.0)
		await physics_frame
		if no_double.wall_action == &"WallRelease":
			break
	var launch_y := no_double.velocity.y
	no_double.set_intent(0.0, true)
	await physics_frame
	check(not no_double.movement_assist.has_active_coyote_window(), "D: WallJump suppresses ground-coyote departure")
	check(no_double.velocity.y >= launch_y, "D: immediate second Jump cannot create a coyote double jump")
	await free_actor(no_double)

	var fatigue := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	fatigue.player_controlled = false
	root.add_child(fatigue)
	var impulses := PackedFloat32Array()
	for attempt in 4:
		fatigue._set_wall_action(&"None")
		fatigue.wall_detach_left = 0.0
		fatigue.wall_coyote_left = 1.0
		fatigue.wall_coyote_side = -1.0
		fatigue.wall_coyote_collider_id = wall.get_instance_id()
		fatigue.move_intent = -1.0
		fatigue._start_wall_jump()
		impulses.append(absf(fatigue.pending_wall_launch.y))
	check(impulses[0] > impulses[1] and impulses[1] > impulses[2] and impulses[3] == 0.0, "E: same-wall vertical impulse decays to zero")
	fatigue._set_wall_action(&"None")
	fatigue.wall_detach_left = 0.0
	fatigue.wall_coyote_left = 1.0
	fatigue.wall_coyote_side = 1.0
	fatigue.wall_coyote_collider_id = wall.get_instance_id() + 1
	fatigue.move_intent = 1.0
	fatigue._start_wall_jump()
	check(is_equal_approx(absf(fatigue.pending_wall_launch.y), fatigue.wall_climb_jump_velocity), "F: opposite/new wall restores full strength")
	fatigue._update_wall_memory(1.0 / 60.0, true)
	check(fatigue.same_wall_jump_count == 0 and fatigue.same_wall_side == 0.0, "G: landing resets same-wall fatigue")
	await free_actor(fatigue)

	wall.queue_free()
	await process_frame
	print("WALL JUMP INTEGRATION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
