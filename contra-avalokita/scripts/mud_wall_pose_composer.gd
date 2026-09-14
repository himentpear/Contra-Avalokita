class_name MudWallPoseComposer
extends RefCounted

const WallFootController = preload("res://scripts/wall_foot_controller.gd")
## Computes anatomically authentic procedural climbing postures for wall movement.
## Decides "what the pose looks like": pelvis offset, spine curvature, foot targets,
## knee hints, arm bends, and transition blending.

@export_group("Wall Pose")
@export var wall_pelvis_distance := 15.0
@export var wall_chest_distance := 8.0
@export var wall_head_distance := 7.0

@export var wall_knee_out := 9.0
@export var wall_knee_down := 4.0

@export var wall_high_foot_y := 11.0
@export var wall_low_foot_y := 24.0

@export var wall_leg_extension_min := 0.70
@export var wall_leg_extension_max := 0.84

@export var wall_arm_extension := 0.84
@export var wall_pelvis_drop := 5.0

var wall_blend := 0.0
var foot_f_ctrl := WallFootController.new()
var foot_b_ctrl := WallFootController.new()
var _prev_action: StringName = &"None"

func reset() -> void:
	wall_blend = 0.0
	foot_f_ctrl = WallFootController.new()
	foot_b_ctrl = WallFootController.new()
	_prev_action = &"None"

class PoseTargets:
	var pelvis_pos: Vector2
	var pelvis_rot: float
	var torso_pos: Vector2
	var torso_rot: float
	var head_rot: float
	var upper_arm_f_pos: Vector2
	var hand_f_target: Vector2
	var hand_b_target: Vector2
	var elbow_f_hint: Vector2
	var elbow_b_hint: Vector2
	var foot_f_target: Vector2
	var foot_b_target: Vector2
	var knee_f_hint: Vector2
	var knee_b_hint: Vector2
	var thigh_f_rot: float
	var shin_f_rot: float
	var foot_f_rot: float
	var thigh_b_rot: float
	var shin_b_rot: float
	var foot_b_rot: float
	var leg_weight: float
	var leg_extension: float
	var arm_extension: float
	var hand_f_weight: float
	var hand_b_weight: float
	var foot_f_weight: float
	var foot_b_weight: float
	var body_weight: float

func update_blend(is_wall_active: bool, delta: float) -> float:
	if delta <= 0.0:
		wall_blend = 1.0 if is_wall_active else 0.0
	else:
		wall_blend = move_toward(wall_blend, 1.0 if is_wall_active else 0.0, delta / 0.10)
	return wall_blend

func compose(character: MudCharacter, delta: float) -> PoseTargets:
	var action := character.wall_action
	var is_wall := action in [&"WallHang", &"WallSlide", &"WallPush", &"WallRelease"]
	var blend := update_blend(is_wall, delta)
	var targets := PoseTargets.new()
	if not is_wall and blend <= 0.001:
		return targets

	var wall_side := character.wall_side
	if wall_side == 0.0:
		wall_side = 1.0
	var wall_x := character.wall_surface_x
	if is_inf(wall_x):
		wall_x = character.global_position.x + wall_side * 12.0
	var plane_x := character.wall_plane_local_x()
	var action_time := character.wall_action_time
	var scrape := character.wall_slide_scrape_offset

	# Base climbing arch parameters in visual local space:
	# Local +X is toward the wall; -X is outward away from the wall.
	var pelvis_dist := wall_pelvis_distance
	var pelvis_y := -33.0 + wall_pelvis_drop
	var pelvis_rot := deg_to_rad(-4.0)
	var torso_pos := Vector2(4.0, -21.0)
	var torso_rot := deg_to_rad(10.0)
	var head_rot := deg_to_rad(-8.0)
	var arm_ext := wall_arm_extension
	var leg_ext := 0.76

	var hand_f_w := 1.0
	var hand_b_w := 0.82
	var foot_f_w := 1.0
	var foot_b_w := 0.88
	var body_w := 1.0

	var hand_anchor_y := character.wall_hand_anchor_y
	if is_zero_approx(hand_anchor_y):
		hand_anchor_y = character.global_position.y - 51.0

	var foot_anchor_y := character.wall_foot_anchor_y
	if is_zero_approx(foot_anchor_y):
		foot_anchor_y = character.global_position.y - 22.0

	var compression := 0.0
	if action == &"WallSlide":
		var total_accum := foot_f_ctrl.stick_accumulation + foot_b_ctrl.stick_accumulation
		compression = clampf(total_accum / (2.0 * maxf(foot_f_ctrl.max_stick_distance, 0.001)), 0.0, 1.0)

	var thigh_f_r := 0.0
	var shin_f_r := 0.0
	var foot_f_r := 0.0
	var thigh_b_r := 0.0
	var shin_b_r := 0.0
	var foot_b_r := 0.0
	var leg_w := 1.0

	match action:
		&"WallHang":
			# Calibrated to exact user reference image (media_1789229132262.png):
			# Pelvis pulled up and back, chest leans in.
			pelvis_dist = 17.0
			pelvis_y = -33.0
			pelvis_rot = deg_to_rad(-3.0)
			torso_pos = Vector2(2.5, -21.5)
			torso_rot = deg_to_rad(8.0)
			head_rot = deg_to_rad(-7.0)
			leg_ext = 0.76
			arm_ext = wall_arm_extension
			var hang_w := smoothstep(0.0, 0.07, action_time)
			hand_f_w = hang_w
			hand_b_w = hang_w * 0.82
			body_w = hang_w
			leg_w = hang_w

			# Front leg: high knee tucked forward near wall (-52 deg), shin flexed down-back (+82 deg)
			thigh_f_r = deg_to_rad(-52.0)
			shin_f_r = deg_to_rad(82.0)
			foot_f_r = deg_to_rad(-30.0)
			# Back leg: lower support leg, thigh (+4 deg), shin reaches forward toward wall (-32 deg)
			thigh_b_r = deg_to_rad(4.0)
			shin_b_r = deg_to_rad(-32.0)
			foot_b_r = deg_to_rad(28.0)

		&"WallSlide":
			# Gentle, relaxed forward curve; legs hang naturally
			pelvis_dist = 15.0
			pelvis_y = -32.0 + scrape * 0.5
			pelvis_rot = deg_to_rad(-2.0)
			torso_pos = Vector2(2.8, -21.0)
			torso_rot = deg_to_rad(10.0)
			head_rot = deg_to_rad(-8.0)
			leg_ext = 0.82
			arm_ext = 0.88
			hand_f_w = 1.0
			hand_b_w = 0.72
			body_w = 1.0
			leg_w = 1.0

			# Micro-dynamics driven by scrape cycle:
			var scrape_cycle := fmod(action_time, 0.18) / 0.18
			var micro_tf := sin(scrape_cycle * TAU) * deg_to_rad(2.0)
			var micro_sf := cos(scrape_cycle * TAU) * deg_to_rad(3.0)
			var micro_tb := sin((scrape_cycle + 0.5) * TAU) * deg_to_rad(1.5)
			var micro_sb := cos((scrape_cycle + 0.5) * TAU) * deg_to_rad(2.0)

			# Relaxed forward-draping slide:
			thigh_f_r = deg_to_rad(-12.0) + micro_tf
			shin_f_r = deg_to_rad(20.0) + micro_sf
			foot_f_r = deg_to_rad(-8.0)
			thigh_b_r = deg_to_rad(-6.0) + micro_tb
			shin_b_r = deg_to_rad(14.0) + micro_sb
			foot_b_r = deg_to_rad(-6.0)

		&"WallPush":
			# Subtle spring compression: slightly distinct from WallSlide, crisp anticipation
			var push_dur := maxf(character.wall_push_duration, 0.001)
			var push_p := clampf(action_time / push_dur, 0.0, 1.0)
			pelvis_dist = lerpf(15.0, 16.2, push_p)
			pelvis_y = lerpf(-32.0, -31.0, push_p)
			pelvis_rot = lerpf(deg_to_rad(-2.0), deg_to_rad(-4.0), push_p)
			torso_pos = Vector2(lerpf(2.8, 3.2, push_p), -21.0)
			torso_rot = lerpf(deg_to_rad(10.0), deg_to_rad(12.0), push_p)
			head_rot = lerpf(deg_to_rad(-8.0), deg_to_rad(-6.0), push_p)
			leg_ext = lerpf(0.82, 0.78, push_p)
			arm_ext = 0.88
			hand_f_w = 1.0
			hand_b_w = 1.0 - push_p * 0.35
			body_w = 1.0
			leg_w = 1.0

			# Subtle knee compression from slide pose (-12° -> -22°, 20° -> 36°):
			thigh_f_r = lerpf(deg_to_rad(-12.0), deg_to_rad(-22.0), push_p)
			shin_f_r = lerpf(deg_to_rad(20.0), deg_to_rad(36.0), push_p)
			foot_f_r = lerpf(deg_to_rad(-8.0), deg_to_rad(-14.0), push_p)
			thigh_b_r = lerpf(deg_to_rad(-6.0), deg_to_rad(-15.0), push_p)
			shin_b_r = lerpf(deg_to_rad(14.0), deg_to_rad(28.0), push_p)
			foot_b_r = lerpf(deg_to_rad(-6.0), deg_to_rad(-12.0), push_p)

		&"WallRelease":
			# Airborne push-off: body propelled away from wall, legs unfolding into airborne trailing
			var rel_dur := maxf(character.wall_release_duration, 0.001)
			var rel_p := clampf(action_time / rel_dur, 0.0, 1.0)
			var body_hold := 1.0 - smoothstep(0.62, 1.0, rel_p)
			var hand_hold := 1.0 - smoothstep(0.24, 0.72, rel_p)
			pelvis_dist = lerpf(16.2, 12.0, rel_p)
			pelvis_y = lerpf(-31.0, -34.0, rel_p)
			pelvis_rot = lerpf(deg_to_rad(-4.0), deg_to_rad(-10.0), rel_p)
			torso_pos = Vector2(lerpf(3.2, 0.5, rel_p), -21.0)
			torso_rot = lerpf(deg_to_rad(12.0), deg_to_rad(-8.0), rel_p)
			head_rot = lerpf(deg_to_rad(-6.0), deg_to_rad(4.0), rel_p)
			leg_ext = lerpf(0.78, 0.88, rel_p)
			arm_ext = 0.85
			hand_f_w = hand_hold
			hand_b_w = 0.0
			body_w = body_hold
			leg_w = body_hold

			# Smooth unfold to air release:
			thigh_f_r = lerpf(deg_to_rad(-22.0), deg_to_rad(-5.0), rel_p)
			shin_f_r = lerpf(deg_to_rad(36.0), deg_to_rad(15.0), rel_p)
			foot_f_r = lerpf(deg_to_rad(-14.0), deg_to_rad(-6.0), rel_p)
			thigh_b_r = lerpf(deg_to_rad(-15.0), deg_to_rad(-2.0), rel_p)
			shin_b_r = lerpf(deg_to_rad(28.0), deg_to_rad(10.0), rel_p)
			foot_b_r = lerpf(deg_to_rad(-12.0), deg_to_rad(-4.0), rel_p)

	targets.pelvis_pos = Vector2(plane_x - pelvis_dist, pelvis_y)
	targets.pelvis_rot = pelvis_rot
	targets.torso_pos = torso_pos
	targets.torso_rot = torso_rot
	targets.head_rot = head_rot
	targets.upper_arm_f_pos = Vector2(4.0, -2.0)

	# Global Contact Targets for hands:
	targets.hand_f_target = Vector2(wall_x - wall_side * 1.5, hand_anchor_y + scrape)
	targets.hand_b_target = Vector2(wall_x - wall_side * 2.5, hand_anchor_y + 9.0 + scrape * 0.5)

	# Elbow hints:
	var away_from_wall := Vector2(-wall_side, 0.0)
	var pelvis_global_y := character.global_position.y + pelvis_y
	var hip_pos_approx := Vector2(character.global_position.x + (plane_x - pelvis_dist) * wall_side, pelvis_global_y)
	var shoulder_approx := hip_pos_approx + Vector2(torso_pos.x * wall_side, torso_pos.y)
	targets.elbow_f_hint = shoulder_approx + away_from_wall * 7.0 + Vector2.DOWN * 8.0
	targets.elbow_b_hint = shoulder_approx + away_from_wall * 9.0 + Vector2.DOWN * 6.0

	# Pose-driven leg outputs:
	targets.thigh_f_rot = thigh_f_r
	targets.shin_f_rot = shin_f_r
	targets.foot_f_rot = foot_f_r
	targets.thigh_b_rot = thigh_b_r
	targets.shin_b_rot = shin_b_r
	targets.foot_b_rot = foot_b_r
	targets.leg_weight = leg_w * blend

	targets.leg_extension = leg_ext
	targets.arm_extension = arm_ext
	targets.hand_f_weight = hand_f_w * blend
	targets.hand_b_weight = hand_b_w * blend
	targets.foot_f_weight = 0.0
	targets.foot_b_weight = 0.0
	targets.body_weight = body_w * blend

	return targets
