extends SceneTree

var failures := 0
var wall_body: StaticBody2D

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

func attach(side: float) -> MudCharacter:
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	actor.position = Vector2(190, 165) if side > 0.0 else Vector2(310, 165)
	actor.velocity = Vector2(105.0 * side, 80.0)
	root.add_child(actor)
	for frame in 90:
		actor.set_intent(side)
		await physics_frame
		if actor.is_wall_attached():
			return actor
	return actor

func release_actor(actor: MudCharacter) -> void:
	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	await process_frame

func launch_from_wall(side: float, input_direction: float) -> MudCharacter:
	var actor := await attach(side)
	check(actor.is_wall_attached(), "%s wall contact is established" % ("right" if side > 0.0 else "left"))
	actor.set_intent(input_direction, true)
	await physics_frame
	check(actor.wall_action == &"WallPush", "Jump request is consumed once into WallPush")
	for frame in 12:
		actor.set_intent(input_direction)
		await physics_frame
		if actor.wall_action == &"WallRelease":
			break
	return actor

func run() -> void:
	var floor_body := platform(Vector2(320, 340), Vector2(640, 20))
	wall_body = platform(Vector2(250, 205), Vector2(20, 270))

	for side in [1.0, -1.0]:
		var climb := await launch_from_wall(side, side)
		check(climb.pending_wall_jump_kind == &"Climb", "Toward + Jump selects Wall Climb on side %.0f" % side)
		check(climb.velocity.x * side < 0.0 and absf(climb.velocity.x) < climb.wall_jump_horizontal_speed, "Wall Climb has the smallest horizontal detach")
		check(climb.velocity.y <= -climb.wall_climb_jump_velocity * 0.75, "Wall Climb has high vertical launch")
		await release_actor(climb)

		var standard := await launch_from_wall(side, 0.0)
		check(standard.pending_wall_jump_kind == &"Standard", "Neutral + Jump selects Standard Wall Jump on side %.0f" % side)
		check(standard.velocity.x * side < -standard.wall_jump_horizontal_speed * 0.70, "Standard Wall Jump launches away from the wall")
		check(standard.velocity.y <= -standard.wall_jump_vertical_speed * 0.75, "Standard Wall Jump preserves medium-high vertical speed")
		await release_actor(standard)

		var kick := await launch_from_wall(side, -side)
		check(kick.pending_wall_jump_kind == &"Kick", "Away + Jump selects Wall Kick on side %.0f" % side)
		check(kick.velocity.x * side < -kick.wall_jump_horizontal_speed, "Wall Kick has the strongest horizontal launch")
		check(kick.velocity.y < 0.0 and absf(kick.velocity.y) < kick.wall_jump_vertical_speed, "Wall Kick trades vertical height for horizontal force")
		check(kick.wall_detach_left > 0.0 and kick.wall_jump_control_lock_left > 0.0, "Wall Kick enables detach and horizontal-control locks")
		await release_actor(kick)

	var coyote := await attach(1.0)
	coyote.set_intent(-1.0)
	await physics_frame
	check(not coyote.is_wall_attached() and coyote.wall_coyote_left > 0.0, "Moving away leaves a short wall-coyote window")
	coyote.set_intent(-1.0, true)
	await physics_frame
	check(coyote.wall_action == &"WallPush" and coyote.pending_wall_jump_kind == &"Kick", "Away then Jump succeeds through wall coyote time")
	await release_actor(coyote)

	var decay_actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	decay_actor.player_controlled = false
	root.add_child(decay_actor)
	var climb_speeds := PackedFloat32Array()
	for attempt in 10:
		decay_actor._set_wall_action(&"None")
		decay_actor.wall_detach_left = 0.0
		decay_actor.wall_coyote_left = 1.0
		decay_actor.wall_coyote_side = 1.0
		decay_actor.wall_coyote_collider_id = wall_body.get_instance_id()
		decay_actor.move_intent = 1.0
		decay_actor._start_wall_jump()
		climb_speeds.append(absf(decay_actor.pending_wall_launch.y))
	var monotonically_decays := true
	for i in range(1, climb_speeds.size()):
		if climb_speeds[i] > climb_speeds[i - 1] + 0.01:
			monotonically_decays = false
	check(monotonically_decays, "Ten same-wall climb impulses decay monotonically")
	check(climb_speeds[0] > climb_speeds[4] and climb_speeds[9] == 0.0, "Same-wall climb eventually becomes detach-only instead of an infinite elevator")
	check(decay_actor.same_wall_jump_count == 10, "Same-wall climb count is tracked per climb jump")
	decay_actor._reset_same_wall_tracking(12345, -1.0)
	check(decay_actor.same_wall_jump_count == 0, "Switching to a different wall resets climb decay")
	decay_actor._reset_same_wall_tracking()
	check(decay_actor.same_wall_jump_count == 0 and decay_actor.same_wall_side == 0.0, "Floor/time reset clears same-wall identity")
	await release_actor(decay_actor)

	var corridor_left := platform(Vector2(400, 205), Vector2(20, 500))
	var corridor_right := platform(Vector2(520, 205), Vector2(20, 500))
	var zigzag := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	zigzag.player_controlled = false
	zigzag.position = Vector2(450, 165)
	zigzag.velocity = Vector2(-105, 80)
	root.add_child(zigzag)
	for frame in 90:
		zigzag.set_intent(-1.0)
		await physics_frame
		if zigzag.is_wall_attached() and zigzag.wall_side < 0.0:
			break
	check(zigzag.is_wall_attached() and zigzag.wall_side < 0.0, "Dual-wall route attaches to the left wall")
	zigzag.set_intent(1.0, true)
	await physics_frame
	var reached_right := false
	for frame in 120:
		zigzag.set_intent(1.0)
		await physics_frame
		if zigzag.is_wall_attached() and zigzag.wall_side > 0.0:
			reached_right = true
			break
	check(reached_right, "Left-wall Kick crosses the corridor and attaches to the right wall")
	if reached_right:
		zigzag.set_intent(-1.0, true)
		await physics_frame
	var returned_left := false
	for frame in 120:
		zigzag.set_intent(-1.0)
		await physics_frame
		if zigzag.is_wall_attached() and zigzag.wall_side < 0.0:
			returned_left = true
			break
	check(returned_left, "Right-wall Kick returns to the left wall for sustained Z climbing")
	await release_actor(zigzag)
	corridor_left.queue_free()
	corridor_right.queue_free()

	floor_body.queue_free()
	wall_body.queue_free()
	await process_frame
	print("WALL JUMP SYSTEM RESULT: ", failures, " failures")
	quit(1 if failures else 0)
