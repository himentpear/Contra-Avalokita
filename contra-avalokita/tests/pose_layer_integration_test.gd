extends SceneTree

var failures := 0
var manager: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func platform(position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return body

func snapshot_bones(actor: MudCharacter) -> Dictionary:
	var result := {}
	for node in actor.skeleton.find_children("*", "Bone2D"):
		var bone := node as Bone2D
		result[String(bone.get_path())] = {"rest": bone.rest, "scale": bone.scale}
	return result

func check_integrity(actor: MudCharacter, snapshot: Dictionary, label: String) -> void:
	var intact := true
	for node in actor.skeleton.find_children("*", "Bone2D"):
		var bone := node as Bone2D
		var saved: Dictionary = snapshot.get(String(bone.get_path()), {})
		if saved.is_empty() or not bone.rest.is_equal_approx(saved.rest) or not bone.scale.is_equal_approx(saved.scale):
			intact = false
	check(intact, label + ": Bone2D rest and scale remain unchanged")
	check(actor.get_arm_extension_ratio(false) <= 1.01 and actor.get_arm_extension_ratio(true) <= 1.01, label + ": both arm chains remain within anatomical reach")
	check(actor.pose_root.position.is_finite(), label + ": PoseRoot remains finite")

func attach_right(actor: MudCharacter) -> bool:
	actor.revive()
	actor.position = Vector2(190, 165)
	actor.velocity = Vector2(105, 80)
	for frame in 90:
		actor.set_intent(1.0)
		await physics_frame
		if actor.is_wall_attached():
			return true
	return false

func run() -> void:
	manager = root.get_node("HitstopManager")
	manager.clear_all_stops()
	var floor_body := platform(Vector2(320, 340), Vector2(640, 20))
	var wall_body := platform(Vector2(250, 205), Vector2(20, 300))
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	actor.position = Vector2(320, 281)
	root.add_child(actor)
	for frame in 8:
		await physics_frame
	var bones := snapshot_bones(actor)

	actor.start_attack(0)
	await physics_frame
	var attack_before_stop := actor.attack_time
	manager.request_manual(actor, null, 0.05)
	for frame in 2:
		await physics_frame
	check(actor.attack_time == attack_before_stop, "Attack -> Hitstop freezes attack and pose clocks")
	while actor.local_time_scale <= 0.0:
		await process_frame
	for frame in 2:
		await physics_frame
	check(actor.attack_time > attack_before_stop, "Attack -> Hitstop resumes without permanent freeze")
	check_integrity(actor, bones, "Attack -> Hitstop -> resume")

	actor.start_attack(1)
	var heavy := HitEvent.new(20.0, Vector2.LEFT, actor.global_position, 120.0, 90.0, &"HeavyHit", &"blade")
	actor.receive_hit(heavy)
	check(not actor.is_attacking() and actor.pose_composer.get_upper_body_owner() == MudPoseComposer.PoseLayer.REACTION, "Attack -> HeavyHit transfers ownership to Reaction")
	manager.clear_actor_stop(actor)
	check_integrity(actor, bones, "Attack -> HeavyHit")

	actor.revive()
	actor.start_attack(0)
	actor.position = Vector2(190, 165)
	actor.velocity = Vector2(105, 80)
	for frame in 90:
		actor.set_intent(1.0)
		await physics_frame
		if actor.is_wall_attached():
			break
	check(actor.is_wall_attached() and not actor.is_attacking() and actor.pose_composer.get_upper_body_owner() == MudPoseComposer.PoseLayer.WALL, "Attack -> Wall contact transfers arm ownership to Wall")
	var wall_hit := HitEvent.new(8.0, Vector2.LEFT, actor.global_position, 60.0, 10.0, &"LightHit", &"unarmed")
	actor.receive_hit(wall_hit)
	check(actor.wall_action == &"None" and actor.pose_composer.get_upper_body_owner() == MudPoseComposer.PoseLayer.REACTION, "WallHang -> Hit clears Wall IK before Reaction")
	manager.clear_actor_stop(actor)
	check_integrity(actor, bones, "Attack/Wall/Reaction handoff")

	check(await attach_right(actor), "WallSlide fixture reaches WallHang")
	for frame in 30:
		actor.set_intent(1.0)
		await physics_frame
		if actor.wall_action == &"WallSlide":
			break
	actor.set_intent(0.0, true)
	await physics_frame
	check(actor.wall_action == &"WallPush", "WallSlide -> WallJump keeps Wall ownership during push")
	for frame in 12:
		actor.set_intent(0.0)
		await physics_frame
		if actor.wall_action == &"WallRelease":
			break
	actor.set_intent(0.0, false, true)
	await physics_frame
	check(actor.is_attacking(), "WallJump -> Attack enters the air-action layer")
	check_integrity(actor, bones, "WallSlide -> WallJump -> Attack")

	actor.revive()
	for stage in 3:
		if not actor.is_attacking():
			actor.start_attack(stage)
		actor.combo_queued = stage < 2
		actor.advance_attack(actor.attack_duration + 0.01)
	check(not actor.is_attacking() and actor.combo_stage == 0, "Attack1 -> Attack2 -> Attack3 exits cleanly to locomotion")
	actor.clear_transient_pose_state()
	actor.pose_composer.evaluate(0.0)
	var root_reference := actor.pose_root.transform
	for frame in 12:
		actor.pose_composer.restore_base()
		actor.pose_composer.evaluate(0.0)
	check(actor.pose_root.transform.is_equal_approx(root_reference), "PoseRoot additive layers do not accumulate frame-to-frame drift")

	var mirror_ratios := PackedFloat32Array()
	for facing in [1.0, -1.0]:
		actor.facing = facing
		actor.visual.scale = Vector2(facing, 1.0)
		actor.start_attack(0)
		actor.attack_time = actor.attack_duration * 0.35
		actor.pose_composer.restore_base()
		actor.pose_composer.evaluate(0.0)
		mirror_ratios.append(actor.get_arm_extension_ratio(false))
		actor.cancel_attack_pose()
	check(absf(mirror_ratios[0] - mirror_ratios[1]) <= 0.01, "Left/right attack mirror symmetry preserves arm extension")
	check_integrity(actor, bones, "Final pose integration")

	actor.impact_accent_offset = Vector2(4, 2)
	actor.reaction_push_offset = Vector2(3, 1)
	actor.pose_composer.weight = 1.0
	actor.pose_composer.wall_composer.wall_blend = 1.0
	actor.revive()
	check(actor.impact_accent_offset == Vector2.ZERO and actor.reaction_push_offset == Vector2.ZERO, "Respawn clears transient action/reaction offsets")
	check(actor.pose_composer.weight == 0.0 and actor.pose_composer.wall_composer.wall_blend == 0.0, "Respawn clears action and Wall IK blend ownership")

	manager.clear_actor_stop(actor)
	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	floor_body.queue_free()
	wall_body.queue_free()
	await process_frame
	print("POSE LAYER INTEGRATION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
