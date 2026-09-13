extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func capture_leg_pose(character: MudCharacter, facing: float) -> Dictionary:
	character.pose_composer.restore_base()
	character.facing = facing
	character.visual.scale = Vector2(facing, 1.0)
	character.state = &"Idle"
	character.anim_player.play(&"Idle", 0.0)
	character.anim_player.seek(0.12, true)
	character.start_attack(1)
	character.attack_time = character.attack_duration * 0.55
	character.pose_composer.last_action_time = -1.0
	character.pose_composer.last_action_stage = -1
	character.pose_composer.evaluate(0.0)

	var pelvis := character.skeleton.get_node("Pelvis") as Bone2D
	var result := {
		"pose_root": character.pose_root.transform,
		"pelvis": pelvis.transform,
	}
	for side in ["Front", "Back"]:
		var thigh := pelvis.get_node("Thigh" + side) as Bone2D
		var shin := thigh.get_node("Shin" + side) as Bone2D
		var foot := shin.get_node("Foot" + side) as Bone2D
		result["thigh_" + side] = thigh.transform
		result["shin_" + side] = shin.transform
		result["foot_" + side] = foot.transform
	return result

func transform_near(a: Transform2D, b: Transform2D, epsilon := 0.0001) -> bool:
	return a.x.distance_to(b.x) <= epsilon and a.y.distance_to(b.y) <= epsilon and a.origin.distance_to(b.origin) <= epsilon

func run() -> void:
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(800.0, 10.0)
	collision.shape = shape
	floor_body.position = Vector2(200.0, 305.0)
	floor_body.add_child(collision)
	root.add_child(floor_body)

	var character := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	character.player_controlled = false
	character.position = Vector2(200.0, 296.0)
	character.scale = Vector2(2.0, 2.0)
	root.add_child(character)
	await physics_frame
	await physics_frame
	character.velocity = Vector2(0.0, 30.0)
	character.move_and_slide()
	check(character.is_on_floor(), "Fixture must stand on floor")
	character.set_physics_process(false)

	var right_pose := capture_leg_pose(character, 1.0)
	var left_pose := capture_leg_pose(character, -1.0)
	for key in right_pose:
		check(transform_near(right_pose[key], left_pose[key]), "Mirroring changed local blade footwork pose: %s" % key)

	var source := FileAccess.get_file_as_string("res://scripts/mud_pose_composer.gd")
	var footwork_source := source.get_slice("func apply_blade_footwork", 1).get_slice("func apply_reaction", 0)
	check(".global_rotation" not in footwork_source, "Blade footwork must not read global_rotation")
	check(".global_transform" not in footwork_source, "Blade footwork must not read or write global_transform")

	character.rig.character = null
	character.rig.gait = null
	character.rig = null
	character.queue_free()
	floor_body.queue_free()
	await process_frame
	print("BLADE FOOTWORK LOCAL SPACE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
