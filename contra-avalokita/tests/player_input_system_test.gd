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

func ensure_input_actions() -> void:
	for action: StringName in [
		&"move_left", &"move_right", &"sprint", &"jump", &"attack", &"block",
		&"equipment", &"weapon_sword", &"weapon_none", &"debug_rig"
	]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

func run() -> void:
	ensure_input_actions()
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = true
	root.add_child(actor)
	await physics_frame

	Input.action_press("move_right")
	await physics_frame
	check(
		is_equal_approx(actor.intent_component.move_direction, actor.walk_speed_ratio)
		and is_equal_approx(actor.move_intent, actor.walk_speed_ratio),
		"PlayerInputSystem forwards walking intent through set_intent"
	)

	Input.action_press("sprint")
	await physics_frame
	check(
		is_equal_approx(actor.intent_component.move_direction, 1.0)
		and is_equal_approx(actor.move_intent, 1.0),
		"PlayerInputSystem preserves sprint intent"
	)

	Input.action_release("move_right")
	Input.action_release("sprint")
	actor.player_controlled = false
	actor.set_intent(-0.5, false, false, true)
	check(
		is_equal_approx(actor.intent_component.move_direction, -0.5)
		and is_equal_approx(actor.move_intent, -0.5)
		and actor.intent_component.block_held,
		"Enemy and scripted controllers continue to use set_intent"
	)

	var character_source := FileAccess.get_file_as_string("res://scripts/mud_character.gd")
	check(not character_source.contains("Input."), "MudCharacter contains no direct Input polling")

	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	await process_frame
	print("PLAYER INPUT SYSTEM RESULT: ", failures, " failures")
	quit(1 if failures else 0)
