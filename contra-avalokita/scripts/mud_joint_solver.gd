class_name MudJointSolver
extends Resource
## Critically damped, substepped spring; damping is per-second, not per-frame.
@export var stiffness := 420.0
@export var damping := 38.0
@export var mass := 1.0
@export var max_lag := 2.0
var target_position := Vector2.ZERO
var current_position := Vector2.ZERO
var velocity := Vector2.ZERO
var initialized := false

func step(target: Vector2, delta: float) -> Vector2:
	target_position = target
	if not initialized:
		current_position = target
		initialized = true
	var remaining := minf(delta, 0.1)
	while remaining > 0.00001:
		var dt := minf(remaining, 1.0 / 120.0)
		velocity += ((target - current_position) * stiffness - velocity * damping) / maxf(mass, 0.01) * dt
		current_position += velocity * dt
		remaining -= dt
	current_position = target + (current_position - target).limit_length(max_lag)
	return current_position

static func compression_for(bend: float) -> float:
	return smoothstep(deg_to_rad(40.0), deg_to_rad(140.0), absf(bend))

