extends SceneTree

const WallFootController = preload("res://scripts/wall_foot_controller.gd")

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
	# IK must preserve the pose supplied by animation, including authored scale.
	var animated_upper_scale := Vector2(1.04, 0.96)
	var animated_lower_scale := Vector2(0.97, 1.03)
	actor._upper_arm_front_bone.scale = animated_upper_scale
	actor._forearm_front_bone.scale = animated_lower_scale
	actor.pose_composer._solve_wall_chain(
		actor._upper_arm_front_bone,
		actor._forearm_front_bone,
		actor._hand_front_bone,
		actor._hand_front_bone.global_position + Vector2(1.0, 0.0),
		1.0,
		0.0
	)
	check(
		actor._upper_arm_front_bone.scale.is_equal_approx(animated_upper_scale)
		and actor._forearm_front_bone.scale.is_equal_approx(animated_lower_scale),
		"Wall IK preserves animated upper-limb scale"
	)
	actor._upper_arm_front_bone.scale = actor._upper_arm_front_bone.rest.get_scale()
	actor._forearm_front_bone.scale = actor._forearm_front_bone.rest.get_scale()
	var front_toe := actor._foot_front_bone.to_global(Vector2(4.2, 0.0))
	check(absf(front_toe.x - actor.wall_surface_x) < 10.0, "Raised foot is visually close to the physical wall plane (allowing natural float): toe=%.2f wall=%.2f" % [front_toe.x, actor.wall_surface_x])
	check((actor._shin_front_bone.global_position.x - actor._thigh_front_bone.global_position.x) * actor.wall_side > 0.0, "WallHang support knee bends forward toward the wall")
	check(actor._foot_front_bone.global_position.y < actor._foot_back_bone.global_position.y - 4.0, "WallHang raises the braced knee and leaves an asymmetric lower support: high=%.2f low=%.2f" % [actor._foot_front_bone.global_position.y, actor._foot_back_bone.global_position.y])
	var elbow_inner_angle := 180.0 - float(actor.body_renderer.angles.get("ArmFront", 180.0))
	check(elbow_inner_angle >= 25.0 and elbow_inner_angle <= 58.0, "WallHang main elbow keeps a natural inner bend: %.1f" % elbow_inner_angle)
	# Spine deformation chain verification:
	check(actor._spine_lower_bone != null and actor._spine_upper_bone != null, "SpineLower and SpineUpper deformation bones exist")
	var spine_ctrl := actor.pose_composer.spine_controller
	check(spine_ctrl != null and spine_ctrl.spine_wall_weight > 0.8, "WallHang engages procedural spine curvature (weight=%.2f)" % [spine_ctrl.spine_wall_weight if spine_ctrl else 0.0])
	check(actor._spine_lower_bone.position.x < -0.5, "SpineLower bows away from the wall in visual space: x=%.2f" % actor._spine_lower_bone.position.x)

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
	check((slide_knee.x - slide_hip.x) * actor.wall_side > 0.0, "WallSlide knee pole bends forward toward the wall: hip=%.2f knee=%.2f" % [slide_hip.x, slide_knee.x])
	check(slide_ankle.y > slide_knee.y + 2.0, "WallSlide ankle stays below the knee: knee_y=%.2f ankle_y=%.2f" % [slide_knee.y, slide_ankle.y])

	# 10-second prolonged slide verification (600 frames at 60Hz) as requested by user spec #35:
	# Verifies: knees never invert, calf doesn't rotate full circle, feet stay below hips,
	# and spine maintains natural curvature throughout.
	var knee_inversion_detected := false
	var foot_above_hip_detected := false
	var calf_spin_detected := false
	for frame in 600:
		actor.set_intent(1.0)
		await physics_frame
		# If actor approaches bottom of test wall, lift back up to continue 10s slide without landing on floor
		if actor.global_position.y > 270.0:
			actor.global_position.y = 190.0
			actor.wall_hand_anchor_y = actor.global_position.y - 51.0
		var hip := actor._thigh_front_bone.global_position
		var knee := actor._shin_front_bone.global_position
		var ankle := actor._foot_front_bone.global_position
		if (knee.x - hip.x) * actor.wall_side <= 0.0:
			knee_inversion_detected = true
		if ankle.y <= hip.y + 2.0:
			foot_above_hip_detected = true
		var shin_rot := wrapf(actor._shin_front_bone.rotation, -PI, PI)
		if shin_rot < 0.2 or shin_rot > 2.0:
			calf_spin_detected = true

	check(not knee_inversion_detected, "10-second prolonged WallSlide (600 frames) never inverts knee pole away from forward wall orientation")
	check(not foot_above_hip_detected, "10-second prolonged WallSlide strictly guarantees feet remain below hips at all times")
	check(not calf_spin_detected, "10-second prolonged WallSlide maintains natural knee flexion without calf spinning")
	check(spine_ctrl.spine_wall_weight >= 0.65, "WallSlide maintains relaxed spine curvature: weight=%.2f" % spine_ctrl.spine_wall_weight)

	actor.set_intent(1.0, true)
	await physics_frame
	check(actor.wall_action == &"WallPush", "Jump input starts the compressed WallPush anticipation")
	check(actor.anim_player.current_animation == &"Wall/Push", "WallPush is driven by the editable Wall/Push AnimationPlayer clip")
	check(absf(actor.velocity.y) < 1.0, "WallPush holds launch velocity during anticipation")
	check((actor._shin_front_bone.global_position.x - actor._thigh_front_bone.global_position.x) * actor.wall_side > 0.0, "WallPush compression keeps the support knee forward toward the wall")
	check(spine_ctrl.spine_wall_weight >= 0.85, "WallPush compresses the spine arch for push anticipation: weight=%.2f" % spine_ctrl.spine_wall_weight)

	var saw_release := false
	for frame in 10:
		actor.set_intent(1.0)
		await physics_frame
		if actor.wall_action == &"WallRelease":
			saw_release = true
			break
	check(saw_release, "WallPush transitions into WallRelease after the compression frames")
	check(actor.anim_player.current_animation == &"Wall/Release", "WallRelease is driven by the editable Wall/Release AnimationPlayer clip")
	check(actor.pending_wall_jump_kind == &"Climb", "Toward-wall input selects Wall Climb Jump")
	check(actor.velocity.x < -actor.wall_climb_detach_velocity * 0.75, "Wall Climb Jump applies a small away-from-wall detach")
	check(actor.velocity.y < -actor.wall_climb_jump_velocity * 0.75, "First Wall Climb Jump launches upward at full strength")
	check(actor.wall_regrab_left > 0.0, "WallJump opens a re-grab cooldown")
	check(actor.jump_phase == &"WallRelease", "Wall release exposes its animation phase")
	check((actor._shin_front_bone.global_position.x - actor._thigh_front_bone.global_position.x) * actor.wall_side > 0.0, "WallRelease preserves the forward knee pole before returning to the airborne pose")

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
