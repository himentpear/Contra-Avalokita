class_name CharacterStateComponent
extends Node

signal locomotion_state_changed(previous: StringName, current: StringName)
signal wall_action_changed(previous: StringName, current: StringName)
signal action_state_changed(previous: StringName, current: StringName)
signal reaction_state_changed(previous: StringName, current: StringName)
signal any_state_changed(category: StringName, previous: StringName, current: StringName)

# --- Locomotion State ---
var _locomotion_state: StringName = &"Idle"
var locomotion_state: StringName:
	get: return _locomotion_state
	set(v):
		if _locomotion_state == v: return
		var prev := _locomotion_state
		_locomotion_state = v
		previous_locomotion_state = prev
		locomotion_state_changed.emit(prev, v)
		any_state_changed.emit(&"locomotion", prev, v)

var state: StringName:
	get: return locomotion_state
	set(v): locomotion_state = v

var previous_locomotion_state: StringName = &"Idle"
var air_time := 0.0
var jump_phase: StringName = &"Grounded"
var land_time := 0.0

# --- Wall State ---
var _wall_action: StringName = &"None"
var wall_action: StringName:
	get: return _wall_action
	set(v):
		if _wall_action == v: return
		var prev := _wall_action
		_wall_action = v
		wall_action_changed.emit(prev, v)
		any_state_changed.emit(&"wall", prev, v)

var wall_side := 0.0
var wall_action_time := 0.0
var wall_hang_left := 0.0
var wall_surface_x := INF
var wall_hand_anchor_y := 0.0
var wall_foot_anchor_y := 0.0
var wall_slide_scrape_offset := 0.0
var wall_front_knee_sign := 0.0
var wall_back_knee_sign := 0.0
var wall_regrab_left := 0.0
var pending_wall_jump_kind: StringName = &"Standard"

# --- Action / Attack State ---
var _action_state: StringName = &"None"
var action_state: StringName:
	get: return _action_state
	set(v):
		if _action_state == v: return
		var prev := _action_state
		_action_state = v
		action_state_changed.emit(prev, v)
		any_state_changed.emit(&"action", prev, v)

var attack_time := 0.0
var attack_requested := false
var combo_stage := 0
var combo_queued := false

# --- Reaction State ---
var _reaction_state: StringName = &"None"
var reaction_state: StringName:
	get: return _reaction_state
	set(v):
		if _reaction_state == v: return
		var prev := _reaction_state
		_reaction_state = v
		reaction_state_changed.emit(prev, v)
		any_state_changed.emit(&"reaction", prev, v)

var reaction_time := 0.0
var reaction_duration := 0.0
var reaction_intensity := 1.0
var reaction_direction := Vector2.RIGHT
var reaction_region: StringName = &"UPPER_TORSO"
var reaction_impact_local := Vector2.ZERO
var reaction_push_offset := Vector2.ZERO

# --- State Query Helpers ---
func is_wall_attached() -> bool:
	return wall_action in [&"WallHang", &"WallSlide"]

func is_wall_jump_action() -> bool:
	return wall_action in [&"WallPush", &"WallRelease"]

func is_wall_hanging() -> bool:
	return wall_action == &"WallHang"

func is_wall_sliding() -> bool:
	return wall_action == &"WallSlide"

func is_wall_pushing() -> bool:
	return wall_action == &"WallPush"

func is_attacking() -> bool:
	return action_state.begins_with("Attack")

func is_reacting() -> bool:
	return reaction_state != &"None"

func is_staggered() -> bool:
	return reaction_state in [&"HeavyHit", &"Knockdown"]

func is_grounded_locomotion() -> bool:
	return locomotion_state in [&"Idle", &"Walk", &"Run"]

func is_airborne_locomotion() -> bool:
	return locomotion_state in [&"Jump", &"Fall"]

func clear_reaction() -> void:
	reaction_state = &"None"
	reaction_time = 0.0
	reaction_duration = 0.0
	reaction_intensity = 1.0
	reaction_direction = Vector2.RIGHT
	reaction_impact_local = Vector2.ZERO
	reaction_push_offset = Vector2.ZERO

func clear_action() -> void:
	action_state = &"None"
	attack_time = 0.0
	attack_requested = false
	combo_stage = 0
	combo_queued = false

func clear_wall() -> void:
	wall_action = &"None"
	wall_side = 0.0
	wall_action_time = 0.0
	wall_hang_left = 0.0
	wall_surface_x = INF
	wall_hand_anchor_y = 0.0
	wall_foot_anchor_y = 0.0
	wall_slide_scrape_offset = 0.0
	wall_front_knee_sign = 0.0
	wall_back_knee_sign = 0.0
	wall_regrab_left = 0.0
	pending_wall_jump_kind = &"Standard"

func clear_transient_pose_state(clear_reaction_flag := true) -> void:
	clear_action()
	if clear_reaction_flag:
		clear_reaction()

func reset_all() -> void:
	clear_wall()
	clear_action()
	clear_reaction()
	locomotion_state = &"Idle"
	air_time = 0.0
	jump_phase = &"Grounded"
	land_time = 0.0
