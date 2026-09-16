extends SceneTree
var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)

func run() -> void:
	var floor_body := StaticBody2D.new()
	var floor_collision := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(2000, 20)
	floor_collision.shape = floor_shape
	floor_body.position = Vector2(0, 70)
	floor_body.add_child(floor_collision)
	root.add_child(floor_body)

	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	actor.position = Vector2(0, 0)
	root.add_child(actor)

	# 1. Kinematic verification of Backstep tracks
	for anim in [&"Backstep", &"Backstep_Unarmed"]:
		check(actor.anim_player.has_animation(anim), "Missing animation: " + String(anim))
		actor.anim_player.play(anim, 0.0)
		var worst_sole := -100.0
		for frame in 120:
			actor.anim_player.seek(frame / 120.0 * actor.anim_player.current_animation_length, true)
			actor._sync_visual(0.0)
			for side in ["Front", "Back"]:
				var foot := actor.skeleton.get_node("Pelvis/Thigh%s/Shin%s/Foot%s" % [side, side, side]) as Bone2D
				var axis := Vector2.RIGHT.rotated(foot.global_rotation)
				var sole := foot.global_position.y + maxf(-axis.y, 4.2 * axis.y) + 3.25
				worst_sole = maxf(worst_sole, sole)
		check(worst_sole < 1.0, "%s ground penetration too deep: %f" % [anim, worst_sole])
		print("PASS: ", anim, " foot contact worst_sole=", worst_sole, " < 1.0")

	# Let actor settle on floor
	for f in 30:
		await physics_frame

	check(actor.is_on_floor(), "Actor must be grounded")

	# 2. Test Forward Attack (facing=1, move_intent=1): must remain Walk or Run
	actor.facing = 1.0
	actor.set_intent(1.0, false, false)
	for f in 15:
		await physics_frame
	check(actor.state in [&"Walk", &"Run"], "Should be moving forward")
	actor.start_attack(0)
	for f in 10:
		actor.set_intent(1.0, false, false)
		await physics_frame
	check(actor.is_attacking(), "Actor should be attacking")
	check(not actor.is_retreating(), "Forward movement must NOT be retreating")
	check(actor.anim_player.current_animation in [&"Walk", &"Run"], "Forward attack must use Walk/Run: " + String(actor.anim_player.current_animation))
	print("PASS: Forward attack preserves Run/Walk animation")

	# Wait for attack to finish
	while actor.is_attacking():
		actor.set_intent(1.0, false, false)
		await physics_frame

	# 3. Test Retreating Attack (facing=1, move_intent=-1): legs must switch to Backstep
	actor.facing = 1.0
	actor.set_intent(-1.0, false, false)
	actor.start_attack(0)
	check(actor.is_attacking(), "Actor should be attacking")
	for f in 15:
		actor.set_intent(-1.0, false, false)
		await physics_frame
		check(actor.facing == 1.0, "Facing direction must remain locked during attack")
		check(actor.is_retreating(), "Facing opposite to move_intent must trigger is_retreating")
		check(actor.anim_player.current_animation == &"Backstep", "Drawn sword retreat must select Backstep: " + String(actor.anim_player.current_animation))

	print("PASS: Retreating attack (facing=1, intent=-1) plays Backstep")

	# Wait for attack to finish while still holding -1
	while actor.is_attacking():
		actor.set_intent(-1.0, false, false)
		await physics_frame

	# After attack finishes, facing updates to intent and returns to Walk/Run
	for f in 5:
		actor.set_intent(-1.0, false, false)
		await physics_frame
	check(not actor.is_retreating(), "After attack ends, is_retreating must be false")
	check(actor.anim_player.current_animation in [&"Walk_Unarmed", &"Run_Unarmed"], "After attack, back carry returns to natural-arm Walk/Run: " + String(actor.anim_player.current_animation))
	print("PASS: After retreating attack ends, smoothly returns to normal movement")

	# 4. Test Symmetrical Retreating Attack (facing=-1, move_intent=1)
	actor.facing = -1.0
	actor.set_intent(1.0, false, false)
	actor.start_attack(0)
	for f in 15:
		actor.set_intent(1.0, false, false)
		await physics_frame
		check(actor.facing == -1.0, "Facing left must remain locked")
		check(actor.is_retreating(), "Facing -1 with intent 1 must trigger is_retreating")
		check(actor.anim_player.current_animation == &"Backstep", "Symmetric drawn-sword retreat must select Backstep: " + String(actor.anim_player.current_animation))

	print("PASS: Symmetric retreat (facing=-1, intent=1) plays Backstep")

	while actor.is_attacking():
		actor.set_intent(1.0, false, false)
		await physics_frame

	# 5. Test Unarmed Retreating Attack
	actor.weapons.equip(null)
	actor.sync_weapon_animation()
	actor.facing = 1.0
	actor.set_intent(-1.0, false, false)
	actor.start_attack(0)
	for f in 15:
		actor.set_intent(-1.0, false, false)
		await physics_frame
		check(actor.is_retreating(), "Unarmed retreat must trigger is_retreating")
		check(actor.anim_player.current_animation == &"Backstep_Unarmed", "Unarmed retreat must select Backstep_Unarmed: " + String(actor.anim_player.current_animation))

	print("PASS: Unarmed retreat plays Backstep_Unarmed")

	# Cleanup
	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	floor_body.queue_free()
	await process_frame

	print("BACKSTEP ATTACK RESULT: ", errors, " failures")
	quit(1 if errors else 0)
