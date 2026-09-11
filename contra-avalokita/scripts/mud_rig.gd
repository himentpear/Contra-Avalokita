class_name MudRig
extends Node2D
## Float-precision FK pose. Flat named anchors make procedural pose replacement simple.
signal foot_contact(side: StringName)
@export_group("Proportions")
@export var torso_length := 22.0
@export var upper_arm_length := 12.0
@export var forearm_length := 12.0
@export var thigh_length := 16.0
@export var shin_length := 16.0
@export var head_radius := 8.2
@export var body_radius := 9.0
@export var arm_radius := 3.7
@export var leg_radius := 5.0
@export_group("Motion")
@export var locomotion_profile: MudLocomotion
@export var joint_phase_delay := 0.045
@export_range(0.0, 0.04) var idle_squash := 0.012
@export_range(1.0, 1.15) var jump_stretch := 1.035
@export_range(0.92, 0.96) var landing_squash := 0.94
@export_range(1.05, 1.12) var attack_stretch := 1.09
@export_range(1.0, 1.15) var heavy_attack_stretch := 1.15
@export var auxiliary_distance := 3.2
@export_range(0.0, 0.5) var inertia_response := 0.22
@export var spring_template: MudJointSolver
var anchors: Dictionary = {}
var springs: Dictionary = {}
var segments: Array[MudSegment] = []
var segment_cursor := 0
var angles: Dictionary = {}
var compressions: Dictionary = {}
var time := 0.0
var stretch := 1.0
var weapon_angle := 0.0
var debug_draw := false
var gait: MudLocomotion
var previous_motion := Vector2.ZERO
var pelvis_history: Array[Vector3] = []
var chest_history: Array[Vector3] = []

func delayed_position(history: Array[Vector3], target: Vector2, delay: float) -> Vector2:
	if history.is_empty() or time > history[-1].x:
		history.append(Vector3(time, target.x, target.y))
	while history.size() > 2 and history[1].x < time - maxf(delay, 0.1):
		history.pop_front()
	var sample_time := time - delay
	for i in range(1, history.size()):
		if history[i].x >= sample_time:
			var a := history[i - 1]
			var b := history[i]
			var alpha := clampf((sample_time - a.x) / maxf(b.x - a.x, 0.0001), 0, 1)
			return Vector2(a.y, a.z).lerp(Vector2(b.y, b.z), alpha)
	return Vector2(history[-1].y, history[-1].z)

func _ready() -> void:
	# Each actor owns its phase and blend state, even when a profile is shared.
	gait = locomotion_profile.duplicate() as MudLocomotion if locomotion_profile else MudLocomotion.new()
	gait.foot_contact.connect(func(side: StringName) -> void: foot_contact.emit(side))

func point(id: StringName) -> Vector2:
	return (anchors[id] as Marker2D).position

func put(id: StringName, p: Vector2, dt: float, lag := false, weight := 1.0) -> void:
	if not anchors.has(id):
		var marker := Marker2D.new()
		marker.name = id
		add_child(marker)
		anchors[id] = marker
	if lag:
		if not springs.has(id):
			var spring := spring_template.duplicate() as MudJointSolver if spring_template else MudJointSolver.new()
			spring.mass *= weight
			springs[id] = spring
		p = (springs[id] as MudJointSolver).step(p, dt)
	(anchors[id] as Marker2D).position = p

func segment(a: Vector2, b: Vector2, r1: float, r2: float, depth := 0.0) -> void:
	if segment_cursor == segments.size(): segments.append(MudSegment.new())
	var s := segments[segment_cursor]
	segment_cursor += 1
	s.start_position = a
	s.end_position = b
	s.radius_start = r1
	s.radius_end = r2
	s.depth = depth

func limb(id: String, origin: Vector2, a: float, bend: float, l1: float, l2: float, radius: float, depth: float, dt: float, reach := 1.0, foot_pitch := 0.0, palm_angle := NAN) -> void:
	bend = clampf(bend, -deg_to_rad(140), deg_to_rad(140))
	var u := Vector2(sin(a), cos(a))
	var v := Vector2(sin(a + bend), cos(a + bend))
	var joint := origin + u * l1 * reach
	var end := joint + v * l2 * reach
	var compression := MudJointSolver.compression_for(bend)
	angles[id] = rad_to_deg(absf(bend))
	compressions[id] = compression
	# Pull controls to the outer bisector; reduce the center radius under folding.
	var outer := -(u - v).normalized() * compression * 0.7
	put(id + "Start", origin, dt)
	put(id + "Joint", joint, dt)
	put(id + "Pre", joint - u * auxiliary_distance + outer, dt, true)
	put(id + "Post", joint + v * auxiliary_distance + outer, dt, true)
	put(id + "End", end, dt, id.begins_with("Arm"), 0.7)
	var jr := radius * (1.0 - compression * 0.14)
	segment(origin, point(id + "Pre"), radius, jr, depth)
	segment(point(id + "Pre"), joint + outer, jr, jr, depth)
	segment(joint + outer, point(id + "Post"), jr, jr, depth)
	segment(point(id + "Post"), point(id + "End"), jr, radius * 0.78, depth)
	if id.begins_with("Leg"):
		var axis := Vector2.RIGHT.rotated(foot_pitch)
		var flatten := gait.foot_flatten(gait.phase + (0.5 if id.ends_with("Back") else 0.0))
		var sole_radius := 3.0 - flatten
		var sole_drop := Vector2.DOWN * flatten
		var heel := end - axis + sole_drop
		var ball := end + axis * 2.6 + sole_drop
		put(id + "Foot", ball, dt)
		put(id + "Heel", heel, dt)
		put(id + "Toe", end + axis * gait.toe_length + sole_drop, dt)
		(anchors[id + "End"] as Marker2D).rotation = foot_pitch
		# Two capsules make heel/full-foot/ball/toe roll readable at pixel scale.
		segment(heel, ball, sole_radius, sole_radius, depth)
		segment(ball, point(id + "Toe"), sole_radius, maxf(1.8, sole_radius - 0.35), depth)
	else:
		var palm := v if is_nan(palm_angle) else Vector2(sin(palm_angle), cos(palm_angle))
		segment(point(id + "End"), point(id + "End") + palm * 2.0, radius, radius * 0.9, depth)

func grounded_leg(id: String, origin: Vector2, cycle: float, rest_a: float, rest_b: float, depth: float, delta: float, blend: float) -> void:
	var rest := origin + Vector2(sin(rest_a), cos(rest_a)) * thigh_length
	rest += Vector2(sin(rest_a + rest_b), cos(rest_a + rest_b)) * shin_length
	var sample := gait.foot(cycle)
	var target := rest.lerp(Vector2(sample.x, sample.y), blend)
	var offset := target - origin
	# Limit maximum IK reach, preserving anatomical bone lengths and enforcing min 5-10 deg flexion
	var max_reach := (thigh_length + shin_length) * lerpf(0.998, 0.985, gait.run_mix)
	var min_reach := absf(thigh_length - shin_length) + 0.1
	var distance := clampf(offset.length(), min_reach, max_reach)
	var cosine := clampf((distance * distance - thigh_length * thigh_length - shin_length * shin_length) / (2.0 * thigh_length * shin_length), -1.0, 1.0)
	# Never allow leg to fully straighten: enforce at least 5-10 degrees of knee flexion
	var min_flexion := deg_to_rad(6.0)
	var bend_mag := clampf(acos(cosine), min_flexion, deg_to_rad(138.0))
	var bend := -bend_mag
	var a := atan2(offset.x, offset.y) - atan2(shin_length * sin(bend), thigh_length + shin_length * cos(bend))
	limb(id, origin, a, bend, thigh_length, shin_length, leg_radius * (0.88 if depth < 0 else 1.0), depth, delta, 1.0, sample.z * blend)

func locomotion_arm(id: String, origin: Vector2, cycle: float, rest_a: float, rest_b: float, depth: float, delta: float, blend: float) -> void:
	var is_weapon := id == "ArmFront"
	var rest := Vector2(sin(rest_a), cos(rest_a)) * upper_arm_length
	rest += Vector2(sin(rest_a + rest_b), cos(rest_a + rest_b)) * forearm_length
	var sample := gait.hand_target(cycle, is_weapon)
	var target := rest.lerp(Vector2(sample.x, sample.y), blend)
	var distance := clampf(target.length(), absf(upper_arm_length - forearm_length) + 0.01, (upper_arm_length + forearm_length) * 0.999)
	var cosine := clampf((distance * distance - upper_arm_length * upper_arm_length - forearm_length * forearm_length) / (2.0 * upper_arm_length * forearm_length), -1.0, 1.0)
	var bend := acos(cosine)
	var a := atan2(target.x, target.y) - atan2(forearm_length * sin(bend), upper_arm_length + forearm_length * cos(bend))
	limb(id, origin, a, bend, upper_arm_length, forearm_length, arm_radius * (0.88 if depth < 0 else 1.0), depth, delta, 1.0, 0.0, a + bend + sample.z * blend)

func pose(delta: float, state: StringName, motion: Vector2, attack_time: float, land_time: float) -> void:
	# Inertia responds to acceleration, not sustained speed: no permanent backward sag.
	var motion_change := motion - previous_motion
	previous_motion = motion
	for spring: MudJointSolver in springs.values():
		spring.velocity -= motion_change * inertia_response
	time += delta
	segment_cursor = 0
	var running := state == &"Run" or state == &"Walk"
	var air := state == &"Jump" or state == &"Fall"
	gait.advance(delta, motion.x, running, thigh_length + shin_length)
	var blend := gait.weight if not air and state != &"Attack" else 0.0
	var phase := gait.phase * TAU
	var delay := gait.cycles_per_second * TAU * joint_phase_delay
	var hip_roll := sin(phase) * gait.hip_roll * blend
	var shoulder_roll := -sin(phase - delay) * gait.shoulder_counter_rotation * blend
	var height := 1.0 + sin(time * 2.6) * idle_squash * (1.0 - blend)
	if state == &"Jump": height = jump_stretch
	if land_time > 0: height = lerpf(1.0, landing_squash, land_time / 0.14)
	var leg_length := thigh_length + shin_length
	var push := maxf(gait.drive(gait.phase), gait.drive(gait.phase + 0.5))
	var load_amount := maxf(gait.acceptance(gait.phase), gait.acceptance(gait.phase + 0.5))
	var pelvis_x := (sin(phase * 2.0) * gait.pelvis_sway + push * gait.drive_push * gait.run_mix) * blend
	var support_height := gait.support_height(pelvis_x, hip_roll, leg_length, gait.phase)
	var hip_height := lerpf(leg_length + 1.0, support_height, blend)
	var pelvis := Vector2(pelvis_x, -hip_height * height)
	
	# Torso lean: 5-7 deg steady run (run_torso_lean_degrees = 6.2 deg)
	var accel_factor := clampf(absf(motion_change.x / maxf(delta, 0.001)) / 700.0, 0.0, 1.0) * gait.run_mix
	var target_lean_deg := lerpf(gait.walk_torso_lean_degrees, gait.run_torso_lean_degrees, gait.run_mix)
	target_lean_deg = lerpf(target_lean_deg, 9.0, accel_factor * 0.7)
	var lean_angle := deg_to_rad(target_lean_deg) * blend
	
	# Pelvis drives the lean forward; head counter-rotates to stay visually stable
	var head_counter_rad := -deg_to_rad(target_lean_deg * 0.55) * blend
	
	var chest_base := delayed_position(pelvis_history, pelvis, gait.chest_delay * blend)
	var torso_vector := Vector2(sin(lean_angle), -cos(lean_angle)) * torso_length * height * (1.0 - load_amount * blend * 0.02)
	var chest := chest_base + torso_vector + Vector2(shoulder_roll * 0.4, 0)
	# Preserve forward intent through flight
	chest.x = maxf(chest.x, pelvis.x + sin(lean_angle) * torso_length * 0.85)
	put(&"Pelvis", pelvis, delta)
	put(&"Chest", chest, delta)
	put(&"Abdomen", pelvis.lerp(chest, 0.46) + Vector2(-shoulder_roll * 0.5, 0), delta, true, 1.4)
	put(&"Neck", point(&"Chest") + Vector2(0, -8), delta)
	var head_base := delayed_position(chest_history, point(&"Chest"), gait.head_delay * blend)
	put(&"Head", head_base + Vector2(1 + sin(lean_angle) * 3.0, -14 + (hip_height - leg_length) * gait.head_stabilization * blend), delta, true, 0.7)
	put(&"ShoulderFront", point(&"Chest") + Vector2(4 + shoulder_roll, shoulder_roll), delta)
	put(&"ShoulderBack", point(&"Chest") + Vector2(-4 - shoulder_roll, -shoulder_roll), delta)
	# Both legs share the same sagittal pivot; depth alone distinguishes front/back.
	put(&"HipFront", pelvis, delta)
	put(&"HipBack", pelvis, delta)
	
	# Pelvis drives forward lean, with subtle opposite chest/pelvis counter-rotation
	(anchors[&"Pelvis"] as Marker2D).rotation = (deg_to_rad(target_lean_deg) * 0.60 - sin(phase) * 0.04) * blend
	(anchors[&"Chest"] as Marker2D).rotation = (deg_to_rad(target_lean_deg) * 0.40 + sin(phase) * 0.05) * blend
	(anchors[&"Head"] as Marker2D).rotation = head_counter_rad
	
	var front_a := 0.38
	var back_a := -0.42
	var front_b := -0.15
	var back_b := 0.20
	stretch = 1.0
	# Stabilized blade angle during locomotion: gentle wrist lag, bounded so it never resembles an attack wind-up
	var target_weapon_angle := -0.58 + front_a * 0.25 + sin(phase - delay * 2.0) * gait.wrist_follow * 0.5 * blend
	target_weapon_angle = clampf(target_weapon_angle, -0.75, -0.25)
	weapon_angle = lerp_angle(weapon_angle, target_weapon_angle, 1.0 - exp(-delta * 14.0))
	if state == &"Attack":
		# Shoulder leads; elbow and wrist start 2-3 frames later.
		var prep := smoothstep(0.0, 0.12, attack_time)
		var swing := smoothstep(0.13, 0.29, attack_time)
		var follow := smoothstep(0.13 + joint_phase_delay, 0.34, attack_time)
		var recover := smoothstep(0.36, 0.62, attack_time)
		front_a = lerpf(0.42 - prep * 1.9 + swing * 3.0, 0.42, recover)
		front_b = lerpf(-0.18 - prep * 1.55 + follow * 1.95, -0.18, recover)
		stretch = 1.0 + (attack_stretch - 1.0) * sin(swing * PI) * (1.0 - recover)
		weapon_angle = lerpf(-0.65 - prep * 1.9 + smoothstep(0.20, 0.34, attack_time) * 3.8, -0.65, recover)
	if air:
		limb("LegBack", pelvis + Vector2(-3, 0), -0.48, -0.12, thigh_length, shin_length, leg_radius * 0.88, -1, delta)
	else:
		grounded_leg("LegBack", point(&"HipBack"), gait.phase + 0.5, -0.18, -0.12, -1, delta, blend)
	locomotion_arm("ArmBack", point(&"ShoulderBack"), gait.phase + 0.5, back_a, back_b, -1, delta, blend)
	segment(pelvis, point(&"Abdomen"), body_radius, body_radius * 0.86)
	segment(point(&"Abdomen"), point(&"Chest"), body_radius * 0.86, body_radius)
	segment(point(&"Chest"), point(&"Head"), 4, 4)
	segment(point(&"Head") + Vector2(0, -1), point(&"Head") + Vector2(0, 1), head_radius, head_radius)
	if air:
		limb("LegFront", pelvis + Vector2(3, 0), 0.64, -0.83, thigh_length, shin_length, leg_radius, 1, delta)
	else:
		grounded_leg("LegFront", point(&"HipFront"), gait.phase, 0.24, -0.18, 1, delta, blend)
	if state == &"Attack":
		limb("ArmFront", point(&"ShoulderFront"), front_a, front_b, upper_arm_length, forearm_length, arm_radius, 1, delta, stretch)
	else:
		locomotion_arm("ArmFront", point(&"ShoulderFront"), gait.phase, front_a, front_b, 1, delta, blend)
	put(&"WristFront", point(&"ArmFrontEnd"), delta)
	put(&"WristBack", point(&"ArmBackEnd"), delta)
	(anchors[&"WristFront"] as Marker2D).rotation = weapon_angle
	(anchors[&"WristBack"] as Marker2D).rotation = (point(&"ArmBackEnd") - point(&"ArmBackJoint")).angle() - PI / 2.0
	queue_redraw()

func _draw() -> void:
	if not debug_draw: return
	draw_polyline(PackedVector2Array([point(&"Pelvis"), point(&"Abdomen"), point(&"Chest"), point(&"Neck"), point(&"Head")]), Color.CORAL, 0.6)
	draw_line(point(&"ShoulderBack"), point(&"ShoulderFront"), Color.CORAL, 0.6)
	draw_line(point(&"HipBack"), point(&"HipFront"), Color.CORAL, 0.6)
	for id in ["ArmFront", "ArmBack", "LegFront", "LegBack"]:
		draw_line(point(id + "Start"), point(id + "Joint"), Color.CYAN, 0.6)
		draw_line(point(id + "Joint"), point(id + "End"), Color.CYAN, 0.6)
		for suffix in ["Pre", "Post"]:
			draw_circle(point(id + suffix), 1.1, Color.YELLOW)
