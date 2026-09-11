class_name MudLocomotion
extends Resource
## One distance-driven cycle, two feet half a cycle apart. Coordinates are facing-local.
signal foot_contact(side: StringName)
@export_group("Gait blend")
@export var walk_speed := 45.0
@export var run_speed := 105.0
@export var blend_response := 7.0
@export_group("Foot trajectory")
@export_range(0.5, 0.75) var walk_stance := 0.50
@export_range(0.25, 0.5) var run_stance := 0.28
@export_range(0.15, 0.5) var walk_step_ratio := 0.34
@export_range(0.15, 0.5) var run_step_ratio := 0.258
@export_range(-0.25, 0.0) var run_landing_bias := -0.155
@export var walk_lift := 9.8
@export var run_lift := 14.0
@export var heel_lift_angle := 0.70
@export var walk_heel_lift_angle := 0.12
@export var heel_strike_angle := -0.18
@export var toe_length := 5.0
@export_group("Weight transfer")
@export var walk_down := 3.1
@export var run_down := 1.5
@export var acceptance_peak := 0.22
@export var acceptance_end := 0.46
@export var drive_push := 1.2
@export var chest_delay := 0.0333
@export var head_delay := 0.0333
@export_range(0.95, 0.999) var walk_support_extension := 0.997
@export_range(0.90, 0.98) var run_support_extension := 0.965
@export_range(0.0, 0.08) var run_contact_compression := 0.030
@export var run_flight_rise := 2.4
@export var pelvis_sway := 0.55
@export var hip_roll := 0.75
@export var hip_half_width := 0.65
@export var shoulder_counter_rotation := 0.85
@export_range(0.0, 8.0) var walk_torso_lean_degrees := 2.5
@export_range(5.0, 10.0) var run_torso_lean_degrees := 6.2
@export var head_stabilization := 0.15
@export_group("Arms")
@export var walk_arm_swing := 0.66
@export var run_arm_swing := 0.90
@export var walk_elbow_bend := 0.40
@export var run_elbow_bend := 1.57
@export var arm_joint_delay := 0.0167
@export var elbow_follow := 0.24
@export var wrist_follow := 0.12
@export var walk_hand_swing := 6.5
@export var run_hand_swing := 5.5
@export var walk_hand_drop := 18.0
@export var run_hand_drop := 15.8
var phase := 0.0
var weight := 0.0
var run_mix := 0.0
var stance := 0.64
var half_step := 9.0
var cycles_per_second := 0.0
var foot_bias := 0.0
var previous_phase := 0.0
var contact_tracking_ready := false
var previous_foot_phases := PackedFloat32Array([0.0, 0.0])

func phase_label() -> String:
	var p := fposmod(contact_phase(phase), 0.5)
	if p > 0.49999: p = 0.0
	if p >= stance: return "Flight"
	var t := p / stance
	if t < 0.1: return "Contact"
	if t < 0.36: return "Down"
	if t < 0.68: return "Passing"
	return "Drive" if run_mix > 0.5 else "Up"

func crossed_phase(from: float, to: float, threshold: float) -> bool:
	var travel := fposmod(to - from, 1.0)
	var distance := fposmod(threshold - from, 1.0)
	return distance > 0.000001 and distance <= travel + 0.000001

func foot_flatten(cycle: float) -> float:
	var p := contact_phase(cycle)
	if p >= stance: return 0.0
	var t := p / stance
	# The mud sole spreads under load, then regains thickness before toe-off.
	return smoothstep(0.05, 0.22, t) * (1.0 - smoothstep(0.58, 0.86, t))

func acceptance(cycle: float) -> float:
	var p := contact_phase(cycle)
	if p >= stance: return 0.0
	var t := p / stance
	return smoothstep(0.0, acceptance_peak, t) * (1.0 - smoothstep(acceptance_peak, acceptance_end, t))

func drive(cycle: float) -> float:
	var p := contact_phase(cycle)
	if p >= stance: return 0.0
	var t := p / stance
	return smoothstep(0.48, 0.86, t) * (1.0 - smoothstep(0.86, 1.0, t))

func arm(cycle: float, is_weapon_arm := false) -> Vector3:
	var p := cycle * TAU
	# 1 frame elbow delay, 2 frame wrist delay
	var delay_elbow := cycles_per_second * TAU * (1.0 / 60.0)
	var delay_wrist := cycles_per_second * TAU * (2.0 / 60.0)
	var swing := lerpf(walk_arm_swing, run_arm_swing, run_mix)
	if is_weapon_arm:
		swing *= 0.40
	else:
		swing *= 1.30
	var center := lerpf(-0.08, -0.48, run_mix)
	var shoulder := center - cos(p) * swing
	# Sample the parent's earlier angle: the elbow cannot reverse with the shoulder.
	var delayed_shoulder := center - cos(p - delay_elbow) * swing
	var bend := lerpf(walk_elbow_bend, run_elbow_bend, run_mix)
	bend += sin(p - delay_elbow) * lerpf(elbow_follow, 0.10, run_mix)
	bend += delayed_shoulder - shoulder
	if run_mix > 0.95: bend = clampf(bend, deg_to_rad(70), deg_to_rad(110))
	var wrist := center - cos(p - delay_wrist) * swing + bend
	wrist += sin(p - delay_wrist) * wrist_follow
	return Vector3(shoulder, bend, wrist)

func hand_target(cycle: float, is_weapon_arm := false) -> Vector3:
	var p := cycle * TAU
	var delay_elbow_cycles := cycles_per_second * (1.0 / 60.0)
	var delay_wrist_cycles := cycles_per_second * (2.0 / 60.0)
	var hand_phase := (cycle - delay_elbow_cycles) * TAU
	var swing := lerpf(walk_hand_swing, run_hand_swing, run_mix)
	var drop := lerpf(walk_hand_drop, run_hand_drop, run_mix)
	if is_weapon_arm:
		swing *= 0.40
		drop -= 1.0 * run_mix
	else:
		swing *= 1.30
	# Constrain the hand around the torso; the upper arm provides the visible pump.
	var x := -cos(hand_phase) * swing
	var y := drop + sin(hand_phase) * lerpf(0.8, 0.6, run_mix) * (0.4 if is_weapon_arm else 1.25)
	var wrist := -sin((cycle - delay_wrist_cycles) * TAU) * wrist_follow
	return Vector3(x, y, wrist)

func contact_phase(cycle: float) -> float:
	# Reference: run stride=0, flight=.1, contact=.2, passing=.3/.4; repeat +.5.
	return fposmod(cycle - 0.2 * run_mix, 1.0)

func flight_lift(cycle: float) -> float:
	if stance >= 0.5: return 0.0
	var p := fposmod(contact_phase(cycle), 0.5)
	if p < stance: return 0.0
	var t := clampf((p - stance) / (0.5 - stance), 0.0, 1.0)
	return sin(PI * t) * run_flight_rise * run_mix

func contact_height(cycle: float, side: int, pelvis_x: float, _roll: float, leg_length: float) -> float:
	var sample := foot(cycle + side * 0.5)
	var dx := sample.x - pelvis_x
	var reach := leg_length * lerpf(walk_support_extension, run_support_extension, run_mix)
	return sqrt(maxf(reach * reach - dx * dx, 0.0)) - sample.y

func support_height(pelvis_x: float, _roll: float, leg_length: float, cycle: float) -> float:
	# WALK: physical ground contact & reach with compression drop
	var walk_h := INF
	var walk_lim := INF
	for side in 2:
		var c := cycle + float(side) * 0.5
		var sample := foot(c)
		var dx := sample.x - pelvis_x
		var reach := leg_length * 0.999
		walk_lim = minf(walk_lim, sqrt(maxf(reach * reach - dx * dx, 0.0)) - sample.y)
		var p := contact_phase(c)
		if p < walk_stance:
			var compression := acceptance(c) * run_contact_compression * run_mix
			reach = leg_length * (walk_support_extension - compression)
			var down := acceptance(c) * walk_down
			walk_h = minf(walk_h, sqrt(maxf(reach * reach - dx * dx, 0.0)) - sample.y - down)
	var final_walk := minf(walk_h, walk_lim)
	
	# RUN: continuous C-infinity Fourier harmonic curve, strictly 3.5 px peak-to-peak
	var u: float = fposmod(cycle - 0.2, 0.5) / 0.5 * TAU
	var h_offset: float = -1.70 * sin(u) + 0.30 * cos(2.0 * u - 0.90)
	var base_reach := leg_length * run_support_extension
	var final_run := base_reach + h_offset
	
	return lerpf(final_walk, final_run, run_mix)

func advance(delta: float, speed: float, moving: bool, leg_length: float) -> void:
	var response := 1.0 - exp(-blend_response * delta)
	weight = lerpf(weight, 1.0 if moving else 0.0, response)
	run_mix = lerpf(run_mix, smoothstep(walk_speed, run_speed, absf(speed)), response)
	stance = lerpf(walk_stance, run_stance, run_mix)
	half_step = maxf(leg_length * lerpf(walk_step_ratio, run_step_ratio, run_mix), 0.1)
	foot_bias = leg_length * run_landing_bias * run_mix
	# During stance, dx/dt = -speed: a planted sole stays still in world space.
	cycles_per_second = absf(speed) * stance / (2.0 * half_step) if moving else 0.0
	previous_phase = phase
	phase = fposmod(phase + delta * cycles_per_second, 1.0)
	var current_foot_phases := PackedFloat32Array([contact_phase(phase), contact_phase(phase + 0.5)])
	if contact_tracking_ready and moving and cycles_per_second > 0.0:
		# Contact is the wrap crossing of each foot's local cycle. This survives skipped frames.
		for side in 2:
			if previous_foot_phases[side] > current_foot_phases[side] and previous_foot_phases[side] - current_foot_phases[side] > 0.5:
				foot_contact.emit(&"Front" if side == 0 else &"Back")
	previous_foot_phases = current_foot_phases
	contact_tracking_ready = true

func foot(cycle: float) -> Vector3:
	var p := contact_phase(cycle)
	
	# WALK foot trajectory
	var walk_pos: Vector3
	if p < walk_stance:
		var t := p / walk_stance
		var wx := lerpf(half_step, -half_step, t)
		var wp := heel_strike_angle * (1.0 - smoothstep(0.0, 0.2, t)) + walk_heel_lift_angle * smoothstep(0.68, 1.0, t)
		var wy := -maxf(toe_length * sin(wp), -sin(wp))
		walk_pos = Vector3(wx, wy, wp)
	else:
		var s := (p - walk_stance) / (1.0 - walk_stance)
		var tangent := -2.0 * half_step * (1.0 - walk_stance) / walk_stance
		var wx := lerpf(-half_step, half_step, smoothstep(0.0, 1.0, s)) + tangent * (2.0 * s * s * s - 3.0 * s * s + s)
		var wy := -walk_lift * pow(sin(PI * s), 1.25)
		var wp := lerpf(walk_heel_lift_angle, heel_strike_angle, smoothstep(0.0, 0.85, s))
		wy -= maxf(toe_length * sin(wp), -sin(wp))
		walk_pos = Vector3(wx, wy, wp)
	
	# RUN foot trajectory: Pose-driven 6 phases (Contact, Compression, Push, Recovery, Knee Drive, Extension)
	var run_pos: Vector3
	if p < run_stance:
		var t := p / run_stance
		var rx := lerpf(half_step, -half_step, t) + foot_bias
		var rp := heel_strike_angle * (1.0 - smoothstep(0.0, 0.2, t)) + heel_lift_angle * smoothstep(0.65, 1.0, t)
		var ry := -maxf(toe_length * sin(rp), -sin(rp))
		run_pos = Vector3(rx, ry, rp)
	else:
		var s := (p - run_stance) / (1.0 - run_stance)
		# Horizontal swing: Recovery lags behind, Knee Drive advances, Extension reaches forward
		var x_start := -half_step + foot_bias
		var x_end := half_step + foot_bias
		var u := 0.0
		if s < 0.28:
			u = smoothstep(0.0, 0.28, s) * 0.22
		elif s < 0.72:
			var t_sub := (s - 0.28) / (0.72 - 0.28)
			u = lerpf(0.22, 0.75, smoothstep(0.0, 1.0, t_sub))
		else:
			var t_sub := (s - 0.72) / (1.0 - 0.72)
			u = lerpf(0.75, 1.0, smoothstep(0.0, 1.0, t_sub))
		var rx := lerpf(x_start, x_end, u)
		
		# Vertical swing: Sharp early recovery lift, high knee-drive clearance, gentle extension descent
		var y_lift := 0.0
		if s < 0.25:
			y_lift = smoothstep(0.0, 0.25, s) * run_lift
		elif s < 0.65:
			var t_sub := (s - 0.25) / (0.65 - 0.25)
			y_lift = lerpf(run_lift, 9.5, smoothstep(0.0, 1.0, t_sub))
		else:
			var t_sub := (s - 0.65) / (1.0 - 0.65)
			y_lift = lerpf(9.5, 0.0, smoothstep(0.0, 1.0, t_sub))
		var rp := lerpf(heel_lift_angle, heel_strike_angle, smoothstep(0.0, 0.90, s))
		var ry := -y_lift - maxf(toe_length * sin(rp), -sin(rp))
		ry -= flight_lift(cycle)
		run_pos = Vector3(rx, ry, rp)
	
	return walk_pos.lerp(run_pos, run_mix)
