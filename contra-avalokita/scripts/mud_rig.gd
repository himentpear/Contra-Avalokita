class_name MudRig
extends Node2D
## Float-precision FK pose. Flat named anchors make procedural pose replacement simple.
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

func _ready() -> void:
	# Each actor owns its phase and blend state, even when a profile is shared.
	gait = locomotion_profile.duplicate() as MudLocomotion if locomotion_profile else MudLocomotion.new()

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

func limb(id: String, origin: Vector2, a: float, bend: float, l1: float, l2: float, radius: float, depth: float, dt: float, reach := 1.0, foot_pitch := 0.0) -> void:
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
		put(id + "Foot", end + axis * 3.0, dt)
		put(id + "Toe", end + axis * gait.toe_length, dt)
		(anchors[id + "End"] as Marker2D).rotation = foot_pitch
		segment(end - axis, point(id + "Toe"), 3.0, 2.8, depth)
	else:
		segment(point(id + "End"), point(id + "End") + v * 1.0, radius, radius * 0.9, depth)

func grounded_leg(id: String, origin: Vector2, cycle: float, rest_a: float, rest_b: float, depth: float, delta: float, blend: float) -> void:
	var rest := origin + Vector2(sin(rest_a), cos(rest_a)) * thigh_length
	rest += Vector2(sin(rest_a + rest_b), cos(rest_a + rest_b)) * shin_length
	var sample := gait.foot(cycle)
	var target := rest.lerp(Vector2(sample.x, sample.y), blend)
	var offset := target - origin
	var distance := clampf(offset.length(), absf(thigh_length - shin_length) + 0.01, (thigh_length + shin_length) * 0.999)
	var cosine := clampf((distance * distance - thigh_length * thigh_length - shin_length * shin_length) / (2.0 * thigh_length * shin_length), -1.0, 1.0)
	# Negative bend chooses the forward knee solution; never flip the knee backwards.
	var bend := -acos(cosine)
	var a := atan2(offset.x, offset.y) - atan2(shin_length * sin(bend), thigh_length + shin_length * cos(bend))
	limb(id, origin, a, bend, thigh_length, shin_length, leg_radius * (0.88 if depth < 0 else 1.0), depth, delta, 1.0, sample.z * blend)

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
	var stride := cos(phase)
	var delay := gait.cycles_per_second * TAU * joint_phase_delay
	var hip_roll := sin(phase) * gait.hip_roll * blend
	var shoulder_roll := -sin(phase - delay) * gait.shoulder_counter_rotation * blend
	var height := 1.0 + sin(time * 2.6) * idle_squash * (1.0 - blend)
	if state == &"Jump": height = jump_stretch
	if land_time > 0: height = lerpf(1.0, landing_squash, land_time / 0.14)
	var leg_length := thigh_length + shin_length
	var pelvis_x := sin(phase) * gait.pelvis_sway * blend
	var support_height := gait.support_height(pelvis_x, hip_roll, leg_length, gait.phase)
	var hip_height := lerpf(leg_length + 1.0, support_height, blend)
	var pelvis := Vector2(pelvis_x, -hip_height * height)
	var lean := lerpf(gait.walk_lean, gait.run_lean, gait.run_mix) * blend
	var chest := pelvis + Vector2(1.5 + lean + shoulder_roll * 0.4, -torso_length * height)
	put(&"Pelvis", pelvis, delta)
	put(&"Chest", chest, delta, true, 1.2)
	put(&"Abdomen", pelvis.lerp(chest, 0.46) + Vector2(-shoulder_roll * 0.5, 0), delta, true, 1.4)
	put(&"Neck", point(&"Chest") + Vector2(0, -8), delta)
	put(&"Head", point(&"Chest") + Vector2(1 + lean * 0.2, -14 + (hip_height - leg_length) * gait.head_stabilization * blend), delta, true, 0.7)
	put(&"ShoulderFront", point(&"Chest") + Vector2(4 + shoulder_roll, shoulder_roll), delta)
	put(&"ShoulderBack", point(&"Chest") + Vector2(-4 - shoulder_roll, -shoulder_roll), delta)
	put(&"HipFront", pelvis + Vector2(lerpf(2.0, gait.hip_half_width, blend), hip_roll), delta)
	put(&"HipBack", pelvis + Vector2(-lerpf(2.0, gait.hip_half_width, blend), -hip_roll), delta)
	var arm_swing := lerpf(gait.walk_arm_swing, gait.run_arm_swing, gait.run_mix)
	var elbow_bend := lerpf(gait.walk_elbow_bend, gait.run_elbow_bend, gait.run_mix)
	var front_a := lerpf(0.42, 0.10 - stride * arm_swing, blend)
	var back_a := lerpf(-0.38, 0.10 + stride * arm_swing, blend)
	var front_b := lerpf(-0.18, elbow_bend + cos(phase - delay) * gait.elbow_follow, blend)
	var back_b := lerpf(0.16, elbow_bend - cos(phase - delay) * gait.elbow_follow, blend)
	stretch = 1.0
	weapon_angle = -0.65 + front_a * 0.5 + sin(phase - delay * 2.0) * gait.wrist_follow * blend
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
	limb("ArmBack", point(&"ShoulderBack"), back_a, back_b, upper_arm_length, forearm_length, arm_radius * 0.88, -1, delta)
	segment(pelvis, point(&"Abdomen"), body_radius, body_radius * 0.86)
	segment(point(&"Abdomen"), point(&"Chest"), body_radius * 0.86, body_radius)
	segment(point(&"Chest"), point(&"Head"), 4, 4)
	segment(point(&"Head") + Vector2(0, -1), point(&"Head") + Vector2(0, 1), head_radius, head_radius)
	if air:
		limb("LegFront", pelvis + Vector2(3, 0), 0.64, -0.83, thigh_length, shin_length, leg_radius, 1, delta)
	else:
		grounded_leg("LegFront", point(&"HipFront"), gait.phase, 0.24, -0.18, 1, delta, blend)
	limb("ArmFront", point(&"ShoulderFront"), front_a, front_b, upper_arm_length, forearm_length, arm_radius, 1, delta, stretch)
	put(&"WristFront", point(&"ArmFrontEnd"), delta)
	put(&"WristBack", point(&"ArmBackEnd"), delta)
	(anchors[&"WristFront"] as Marker2D).rotation = weapon_angle
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
