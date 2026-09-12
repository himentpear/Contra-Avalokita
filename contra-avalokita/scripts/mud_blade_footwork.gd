class_name MudBladeFootwork
extends Resource
## Offsets are sampled on top of this frame's locomotion, never a replacement stance.
@export var idle_weight := 1.0
@export var walk_weight := 0.65
@export var run_weight := 0.35
@export var pelvis_push := Vector3(5.0,5.0,8.0)
@export var front_step := Vector3(4.0,2.5,6.5)
@export var anticipation_sink := Vector3(1.5,2.0,4.0)
@export var anticipation_back := Vector3(.8,2.5,3.0)
@export var heavy_hold_seconds := 0.05

func sample(stage: int, p: float) -> Dictionary:
	stage = clampi(stage,0,2)
	var load := smoothstep(0.0,.18,p)*(1.0-smoothstep(.20,.42,p))
	var drive := smoothstep(.20,.50,p)*(1.0-smoothstep(.72,1.0,p))
	var step := smoothstep(.20,.48,p)*(1.0-smoothstep(.84,1.0,p))
	var impact := smoothstep(.52,.60,p)*(1.0-smoothstep(.78,1.0,p)) if stage == 2 else 0.0
	return {"pelvis":Vector2(pelvis_push[stage]*drive-anticipation_back[stage]*load,anticipation_sink[stage]*load+impact*1.5),"front":Vector2(front_step[stage]*step,0),"back":Vector2(impact*1.5,0),"heel":(.12 if stage == 0 else .32)*drive}

func influence(movement: StringName) -> float:
	match movement:
		&"Idle": return idle_weight
		&"Walk": return walk_weight
		&"Run": return run_weight
	return 0.0
