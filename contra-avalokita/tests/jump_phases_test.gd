extends SceneTree
var landings := 0
var hard_landings := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4000,20)
	collision.shape = shape
	floor_body.position.y = 90
	floor_body.add_child(collision)
	root.add_child(floor_body)
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	actor.position.y = 78
	root.add_child(actor)
	actor.landed.connect(func(_speed: float, hard: bool) -> void:
		landings += 1
		if hard: hard_landings += 1
	)
	for frame in 12: await physics_frame
	check(landings == 0,"Standing / short spawn settling must not trigger landing")
	for intent in [0.0,.43,1.0]:
		var phases := {}
		var before := landings
		actor.set_intent(intent,true)
		for frame in 95:
			if frame == 15: actor.start_attack(1)
			await physics_frame
			phases[actor.jump_phase] = true
		for phase in [&"JumpSquat",&"Takeoff",&"Rise",&"Apex",&"Fall",&"SoftLand",&"Recovery",&"Grounded"]:
			check(phases.has(phase),"Missing jump phase: "+String(phase))
		check(landings == before+1,"Landing must fire exactly once per jump")
		var expected: StringName = &"Idle" if intent == 0 else (&"Walk" if intent < .6 else &"Run")
		check(actor.state == expected,"Recover to current locomotion")
		check(actor.anim_player.current_animation == expected and actor.anim_player.is_playing(),"Landing must resume playing the actual locomotion clip, not only change state")
		var playback_before := actor.anim_player.current_animation_position
		for tick in 4: await physics_frame
		check(not is_equal_approx(actor.anim_player.current_animation_position,playback_before),"Recovered locomotion timeline must keep advancing")
		print("PASS phase sequence, single landing event, locomotion recovery: ",actor.state)
	actor.position.y = -180
	actor.velocity.y = 100
	for frame in 100: await physics_frame
	check(hard_landings == 1,"High drop must select hard landing")
	var count := landings
	for frame in 30: await physics_frame
	check(landings == count,"Remaining grounded must not retrigger landing")
	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	floor_body.queue_free()
	await process_frame
	print("JUMP RESULT: ",failures," failures")
	quit(1 if failures else 0)
