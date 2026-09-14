class_name WallFootController
extends RefCounted
## Manages cyclical Stick -> Compress -> Slip -> Replant foot mechanics on a wall.
## Prevents open-loop displacement accumulation and guarantees anatomical constraints.

enum State {
	STICK,
	COMPRESS,
	SLIP,
	REPLANT,
}

var state: State = State.STICK
var anchor_pos := Vector2.ZERO
var target_pos := Vector2.ZERO
var slip_start_pos := Vector2.ZERO
var slip_target_pos := Vector2.ZERO
var slip_progress := 1.0
var stick_accumulation := 0.0
var phase_offset := 0.0

@export var max_stick_distance := 8.0
@export var slip_step := 12.0
@export var slip_duration := 0.08
@export var min_extension := 0.64
@export var max_extension := 0.86
@export var min_foot_drop_below_hip := 5.0
@export var max_foot_drop_below_hip := 34.0

func initialize(initial_pos: Vector2, phase: float = 0.0) -> void:
	anchor_pos = initial_pos
	target_pos = initial_pos
	slip_start_pos = initial_pos
	slip_target_pos = initial_pos
	slip_progress = 1.0
	stick_accumulation = phase * max_stick_distance
	phase_offset = phase
	state = State.STICK

func trigger_slip(hip_pos: Vector2, wall_x: float, wall_side: float, wall_offset_x: float, target_drop_below_hip: float) -> void:
	state = State.SLIP
	slip_start_pos = target_pos
	slip_progress = 0.0
	stick_accumulation = 0.0
	var new_y := hip_pos.y + target_drop_below_hip
	new_y = clampf(new_y, hip_pos.y + min_foot_drop_below_hip, hip_pos.y + max_foot_drop_below_hip)
	slip_target_pos = Vector2(wall_x - wall_side * wall_offset_x, new_y)

func step(hip_pos: Vector2, wall_x: float, wall_side: float, wall_offset_x: float, target_drop_below_hip: float, delta: float, leg_length: float = 32.0) -> Vector2:
	if anchor_pos == Vector2.ZERO:
		initialize(Vector2(wall_x - wall_side * wall_offset_x, hip_pos.y + target_drop_below_hip), phase_offset)

	var desired_x := wall_x - wall_side * wall_offset_x

	match state:
		State.STICK, State.COMPRESS:
			# Anchor stays fixed on the wall surface
			target_pos.x = desired_x
			target_pos.y = anchor_pos.y

			# Evaluate compression
			var distance := hip_pos.distance_to(target_pos)
			var ext := distance / maxf(leg_length, 0.001)
			var drop_below_hip := target_pos.y - hip_pos.y

			# Accumulate displacement
			stick_accumulation += absf(hip_pos.y + target_drop_below_hip - target_pos.y) * delta * 8.0

			if drop_below_hip < min_foot_drop_below_hip or ext < min_extension or stick_accumulation >= max_stick_distance:
				trigger_slip(hip_pos, wall_x, wall_side, wall_offset_x, target_drop_below_hip)
			elif ext < (min_extension + 0.08):
				state = State.COMPRESS
			else:
				state = State.STICK

		State.SLIP:
			slip_progress += (delta / maxf(slip_duration, 0.001)) if delta > 0.0 else 1.0
			# Ease-out cubic for realistic initial slip snap into friction lock
			var t := clampf(slip_progress, 0.0, 1.0)
			var ease_t := 1.0 - pow(1.0 - t, 3.0)
			target_pos = slip_start_pos.lerp(slip_target_pos, ease_t)
			target_pos.x = desired_x

			if slip_progress >= 1.0:
				state = State.REPLANT
				anchor_pos = slip_target_pos
				target_pos = slip_target_pos

		State.REPLANT:
			anchor_pos = target_pos
			stick_accumulation = 0.0
			state = State.STICK

	# Hard anatomical guarantee: Foot.y MUST ALWAYS be below Hip.y
	target_pos.y = clampf(target_pos.y, hip_pos.y + min_foot_drop_below_hip, hip_pos.y + max_foot_drop_below_hip)
	target_pos.x = desired_x
	return target_pos
