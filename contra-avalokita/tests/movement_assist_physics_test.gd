extends SceneTree

var failures := 0
var floor_body: StaticBody2D

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func make_actor(at: Vector2) -> MudCharacter:
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	actor.position = at
	root.add_child(actor)
	return actor

func dispose(actor: MudCharacter) -> void:
	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	await process_frame

func wait_until_airborne(actor: MudCharacter, max_ticks := 120) -> bool:
	for tick in max_ticks:
		await physics_frame
		if not actor.is_on_floor(): return true
	return false

func run() -> void:
	floor_body = StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100.0, 20.0)
	collision.shape = shape
	floor_body.position = Vector2(100.0, 110.0)
	floor_body.add_child(collision)
	root.add_child(floor_body)

	# Natural departure followed by a Coyote jump.
	var actor := make_actor(Vector2(120.0, 98.0))
	for tick in 8: await physics_frame
	actor.set_intent(1.0)
	check(await wait_until_airborne(actor), "Actor naturally leaves platform")
	for tick in 2: await physics_frame
	actor.set_intent(1.0, true)
	await physics_frame
	check(actor.velocity.y < 0.0 and actor.movement_assist.last_jump_source == MudMovementAssist.JumpSource.COYOTE, "Physical Coyote jump succeeds inside base window")
	await dispose(actor)

	# The same departure fails after the permission expires.
	actor = make_actor(Vector2(120.0, 98.0))
	for tick in 8: await physics_frame
	actor.set_intent(1.0)
	check(await wait_until_airborne(actor), "Expired fixture naturally leaves platform")
	for tick in 8: await physics_frame
	actor.set_intent(1.0, true)
	await physics_frame
	check(actor.velocity.y >= 0.0 and actor.movement_assist.last_jump_source == MudMovementAssist.JumpSource.NONE, "Physical jump fails after Coyote expiration")
	await dispose(actor)

	# A regular ground jump never opens a second ground permission.
	actor = make_actor(Vector2(100.0, 98.0))
	for tick in 8: await physics_frame
	actor.set_intent(0.0, true)
	for tick in 7: await physics_frame
	var before_second_press := actor.velocity.y
	actor.set_intent(0.0, true)
	await physics_frame
	check(actor.movement_assist.last_jump_source == MudMovementAssist.JumpSource.GROUND and actor.velocity.y > before_second_press, "Physical ground jump cannot reset itself through Coyote")
	await dispose(actor)

	# A late airborne edge press survives until the landing transition and launches.
	actor = make_actor(Vector2(100.0, 25.0))
	var registered := false
	for tick in 120:
		await physics_frame
		if not registered and actor.position.y >= 78.0 and not actor.is_on_floor():
			actor.set_intent(0.0, true)
			registered = true
		if registered and actor.movement_assist.last_jump_source == MudMovementAssist.JumpSource.BUFFERED_GROUND:
			break
	check(registered and actor.movement_assist.last_jump_source == MudMovementAssist.JumpSource.BUFFERED_GROUND and actor.velocity.y < 0.0, "Physical pre-landing input performs an immediate buffered jump")
	await dispose(actor)

	floor_body.queue_free()
	await process_frame
	print("MOVEMENT ASSIST PHYSICS RESULT: ", failures, " failures")
	quit(1 if failures else 0)
