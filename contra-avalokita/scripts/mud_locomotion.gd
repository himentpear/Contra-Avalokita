class_name MudLocomotion
extends Resource
## One distance-driven cycle, two feet half a cycle apart. Coordinates are facing-local.
@export_group("Gait blend")
@export var walk_speed := 45.0
@export var run_speed := 105.0
@export var blend_response := 12.0
@export_group("Foot trajectory")
@export_range(0.5, 0.75) var walk_stance := 0.50
@export_range(0.25, 0.5) var run_stance := 0.36
@export_range(0.15, 0.5) var walk_step_ratio := 0.34
@export_range(0.15, 0.5) var run_step_ratio := 0.44
@export var walk_lift := 4.5
@export var run_lift := 14.0
@export var heel_lift_angle := 0.48
@export var walk_heel_lift_angle := 0.12
@export var heel_strike_angle := -0.18
@export var toe_length := 5.0
@export_group("Weight transfer")
@export_range(0.95, 0.999) var walk_support_extension := 0.997
@export_range(0.92, 0.999) var run_support_extension := 0.985
@export_range(0.0, 0.08) var run_contact_compression := 0.025
@export var run_flight_rise := 4.0
@export var pelvis_sway := 0.25
@export var hip_roll := 0.2
@export var hip_half_width := 0.65
@export var shoulder_counter_rotation := 1.2
@export var walk_lean := 0.8
@export var run_lean := 5.0
@export var head_stabilization := 0.15
@export_group("Arms")
@export var walk_arm_swing := 0.46
@export var run_arm_swing := 0.78
@export var walk_elbow_bend := 0.40
@export var run_elbow_bend := 0.95
@export var elbow_follow := 0.24
@export var wrist_follow := 0.12
var phase := 0.0
var weight := 0.0
var run_mix := 0.0
var stance := 0.64
var half_step := 9.0
var cycles_per_second := 0.0

func contact_phase(cycle: float) -> float:
	# Reference: run stride=0, flight=.1, contact=.2, passing=.3/.4; repeat +.5.
	return fposmod(cycle - 0.2 * run_mix, 1.0)

func flight_lift(cycle: float) -> float:
	if stance >= 0.5: return 0.0
	var p := fposmod(contact_phase(cycle), 0.5)
	var t := clampf((p - stance) / (0.5 - stance), 0.0, 1.0)
	return sin(PI * t) * run_flight_rise * run_mix

func contact_height(cycle: float, side: int, pelvis_x: float, roll: float, leg_length: float) -> float:
	var sample := foot(cycle + side * 0.5)
	var sign_side := 1.0 if side == 0 else -1.0
	var dx := sample.x - (pelvis_x + hip_half_width * sign_side)
	var reach := leg_length * lerpf(walk_support_extension, run_support_extension, run_mix)
	return sqrt(maxf(reach * reach - dx * dx, 0.0)) - sample.y + roll * sign_side

func support_height(pelvis_x: float, roll: float, leg_length: float, cycle: float) -> float:
	var limit := INF
	var height := INF
	for side in 2:
		var c := cycle + side * 0.5
		var sample := foot(c)
		var sign_side := 1.0 if side == 0 else -1.0
		var dx := sample.x - (pelvis_x + hip_half_width * sign_side)
		var local_roll := roll * sign_side
		# Highest reachable pelvis for either foot, including a lifted swing foot.
		var reach := leg_length * 0.999
		limit = minf(limit, sqrt(maxf(reach * reach - dx * dx, 0.0)) - sample.y + local_roll)
		var p := contact_phase(c)
		if p < stance:
			var t := p / stance
			var compression := sin(PI * t) * run_contact_compression * run_mix
			reach = leg_length * (lerpf(walk_support_extension, run_support_extension, run_mix) - compression)
			height = minf(height, sqrt(maxf(reach * reach - dx * dx, 0.0)) - sample.y + local_roll)
	if is_inf(height):
		# A genuine flight interval: pelvis rises while both feet leave the floor.
		var p := fposmod(contact_phase(cycle), 0.5)
		var t := clampf((p - stance) / (0.5 - stance), 0.0, 1.0)
		var last_side := 0 if contact_phase(cycle) < 0.5 else 1
		var takeoff := contact_height(cycle - (p - stance), last_side, pelvis_x, roll, leg_length)
		var landing := contact_height(cycle + (0.5 - p), 1 - last_side, pelvis_x, roll, leg_length)
		height = lerpf(takeoff, landing, smoothstep(0.0, 1.0, t)) + flight_lift(cycle)
	return minf(height, limit)

func advance(delta: float, speed: float, moving: bool, leg_length: float) -> void:
	var response := 1.0 - exp(-blend_response * delta)
	weight = lerpf(weight, 1.0 if moving else 0.0, response)
	run_mix = lerpf(run_mix, smoothstep(walk_speed, run_speed, absf(speed)), response)
	stance = lerpf(walk_stance, run_stance, run_mix)
	half_step = maxf(leg_length * lerpf(walk_step_ratio, run_step_ratio, run_mix), 0.1)
	# During stance, dx/dt = -speed: a planted sole stays still in world space.
	cycles_per_second = absf(speed) * stance / (2.0 * half_step) if moving else 0.0
	phase = fposmod(phase + delta * cycles_per_second, 1.0)

func foot(cycle: float) -> Vector3:
	var p := contact_phase(cycle)
	var x: float
	var y := 0.0
	var pitch: float
	var toe_off := lerpf(walk_heel_lift_angle, heel_lift_angle, run_mix)
	if p < stance:
		var t := p / stance
		x = lerpf(half_step, -half_step, t)
		pitch = heel_strike_angle * (1.0 - smoothstep(0.0, 0.2, t))
		pitch += toe_off * smoothstep(0.68, 1.0, t)
	else:
		var t := (p - stance) / (1.0 - stance)
		# Hermite tangent matches stance velocity at both ends, avoiding a kick/pop.
		var tangent := -2.0 * half_step * (1.0 - stance) / stance
		x = lerpf(-half_step, half_step, smoothstep(0.0, 1.0, t))
		x += tangent * (2.0 * t * t * t - 3.0 * t * t + t)
		# Fold early on recovery, then extend the shin BEFORE the next contact.
		var recovery := lerpf(1.0, 1.0 - smoothstep(0.35, 0.95, t), run_mix)
		y = -lerpf(walk_lift, run_lift, run_mix) * pow(sin(PI * t), 1.4) * recovery
		pitch = lerpf(toe_off, heel_strike_angle, smoothstep(0.0, 0.85, t))
	# Rotate about the supporting toe/heel instead of pushing the foot into the floor.
	y -= maxf(toe_length * sin(pitch), -sin(pitch))
	y -= flight_lift(cycle)
	return Vector3(x, y, pitch)
