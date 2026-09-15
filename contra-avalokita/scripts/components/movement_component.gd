class_name MovementComponent
extends Node

const IntentComponentScript = preload("res://gameplay/components/movement/intent_component.gd")

signal movement_state_changed(state: StringName)
signal landed(impact_speed: float, hard: bool)
signal wall_action_changed(previous: StringName, current: StringName)
signal wall_jumped(direction: Vector2)
signal footstep(side: StringName)
signal unfallen_started(duration: float)
signal unfallen_ended
signal jump_executed(source: MudMovementAssist.JumpSource)

@export_group("Locomotion")
@export var move_speed := 105.0
@export_range(0.1, 0.9) var walk_speed_ratio := 0.43
@export var acceleration := 700.0
@export var gravity := 650.0
@export var jump_velocity := -245.0
@export var jump_squat_duration := 0.075
@export var takeoff_duration := 0.075
@export var minimum_landing_air_time := 0.08
@export var soft_landing_speed := 140.0
@export var hard_landing_speed := 280.0
@export var apex_threshold := 35.0
@export var landing_recovery_duration := 0.07

@export_group("Movement Assist")
@export_range(0.0, 0.40, 0.005) var base_coyote_time := 0.10
@export_range(0.0, 0.30, 0.005) var base_jump_buffer_time := 0.08
@export var movement_assist_debug := false

@export_group("Wall Movement")
@export var wall_slide_speed := 58.0
@export var wall_hang_duration := 0.24
@export var wall_stick_speed := 18.0
@export var wall_grab_upward_limit := 85.0
@export var wall_climb_jump_velocity := 245.0
@export var wall_climb_detach_velocity := 55.0
@export var wall_jump_horizontal_speed := 185.0
@export var wall_jump_vertical_speed := 238.0
@export var wall_kick_horizontal_velocity := 260.0
@export var wall_kick_velocity := 205.0
@export var wall_push_duration := 0.075
@export var wall_release_duration := 0.14
@export_range(0.0, 0.30, 0.005) var wall_coyote_time := 0.12
@export_range(0.0, 0.30, 0.005) var wall_detach_time := 0.14
@export_range(0.0, 0.12, 0.005) var wall_detach_grace := 0.06
@export_range(0.0, 0.30, 0.005) var wall_jump_control_lock_time := 0.10
@export_range(0.0, 1.0, 0.05) var wall_jump_air_control := 0.25
@export_range(0.0, 1.0, 0.01) var wall_input_deadzone := 0.10
@export_range(0.0, 1.0, 0.01) var same_wall_reset_time := 0.40
@export var wall_climb_decay := PackedFloat32Array([1.00, 0.75, 0.45, 0.0])

@export_group("Wall IK")
@export var wall_max_foot_lag := 7.0
@export var wall_min_foot_below_hip := 5.0

# Runtime state
var character: CharacterBody2D
var state_component: Node

var _air_time := 0.0
var air_time: float:
	get: return state_component.air_time if state_component else _air_time
	set(v):
		if state_component: state_component.air_time = v
		else: _air_time = v

var last_air_velocity_y := 0.0

var _jump_phase: StringName = &"Grounded"
var jump_phase: StringName:
	get: return state_component.jump_phase if state_component else _jump_phase
	set(v):
		if state_component: state_component.jump_phase = v
		else: _jump_phase = v

var jump_squat_left := 0.0
var landing_left := 0.0
var landing_animation: StringName = &""
var grounded_resume_phase := 0.0
var movement_assist := MudMovementAssist.new()
var item_inventory := MudItemInventory.new()
var pending_jump_source := MudMovementAssist.JumpSource.NONE

var _wall_action: StringName = &"None"
var wall_action: StringName:
	get: return state_component.wall_action if state_component else _wall_action
	set(v):
		if state_component: state_component.wall_action = v
		else: _wall_action = v

var _wall_side := 0.0
var wall_side: float:
	get: return state_component.wall_side if state_component else _wall_side
	set(v):
		if state_component: state_component.wall_side = v
		else: _wall_side = v

var _wall_action_time := 0.0
var wall_action_time: float:
	get: return state_component.wall_action_time if state_component else _wall_action_time
	set(v):
		if state_component: state_component.wall_action_time = v
		else: _wall_action_time = v

var _wall_hang_left := 0.0
var wall_hang_left: float:
	get: return state_component.wall_hang_left if state_component else _wall_hang_left
	set(v):
		if state_component: state_component.wall_hang_left = v
		else: _wall_hang_left = v

var _wall_regrab_left := 0.0
var wall_regrab_left: float:
	get: return state_component.wall_regrab_left if state_component else _wall_regrab_left
	set(v):
		if state_component: state_component.wall_regrab_left = v
		else: _wall_regrab_left = v

var wall_coyote_left := 0.0
var wall_detach_left := 0.0
var wall_jump_control_lock_left := 0.0
var wall_detach_grace_left := 0.0
var wall_coyote_side := 0.0
var wall_coyote_collider_id := 0
var same_wall_jump_count := 0
var same_wall_collider_id := 0
var same_wall_side := 0.0
var same_wall_reset_left := 0.0

var _pending_wall_jump_kind: StringName = &"Standard"
var pending_wall_jump_kind: StringName:
	get: return state_component.pending_wall_jump_kind if state_component else _pending_wall_jump_kind
	set(v):
		if state_component: state_component.pending_wall_jump_kind = v
		else: _pending_wall_jump_kind = v

var pending_wall_launch := Vector2.ZERO

var _wall_surface_x := INF
var wall_surface_x: float:
	get: return state_component.wall_surface_x if state_component else _wall_surface_x
	set(v):
		if state_component: state_component.wall_surface_x = v
		else: _wall_surface_x = v

var _wall_hand_anchor_y := 0.0
var wall_hand_anchor_y: float:
	get: return state_component.wall_hand_anchor_y if state_component else _wall_hand_anchor_y
	set(v):
		if state_component: state_component.wall_hand_anchor_y = v
		else: _wall_hand_anchor_y = v

var _wall_foot_anchor_y := 0.0
var wall_foot_anchor_y: float:
	get: return state_component.wall_foot_anchor_y if state_component else _wall_foot_anchor_y
	set(v):
		if state_component: state_component.wall_foot_anchor_y = v
		else: _wall_foot_anchor_y = v

var _wall_slide_scrape_offset := 0.0
var wall_slide_scrape_offset: float:
	get: return state_component.wall_slide_scrape_offset if state_component else _wall_slide_scrape_offset
	set(v):
		if state_component: state_component.wall_slide_scrape_offset = v
		else: _wall_slide_scrape_offset = v

var _wall_front_knee_sign := 0.0
var wall_front_knee_sign: float:
	get: return state_component.wall_front_knee_sign if state_component else _wall_front_knee_sign
	set(v):
		if state_component: state_component.wall_front_knee_sign = v
		else: _wall_front_knee_sign = v

var _wall_back_knee_sign := 0.0
var wall_back_knee_sign: float:
	get: return state_component.wall_back_knee_sign if state_component else _wall_back_knee_sign
	set(v):
		if state_component: state_component.wall_back_knee_sign = v
		else: _wall_back_knee_sign = v

var facing := 1.0
var move_intent := 0.0
var jump_requested := false

var _land_time := 0.0
var land_time: float:
	get: return state_component.land_time if state_component else _land_time
	set(v):
		if state_component: state_component.land_time = v
		else: _land_time = v

var _current_movement_state: StringName = &"Idle"
var current_movement_state: StringName:
	get: return state_component.locomotion_state if state_component else _current_movement_state
	set(v):
		if state_component: state_component.locomotion_state = v
		else: _current_movement_state = v

func setup(p_character: CharacterBody2D, p_state_component: Node = null) -> void:
	character = p_character
	state_component = p_state_component
	movement_assist.configure(base_coyote_time, base_jump_buffer_time)
	if not item_inventory.changed.is_connected(_recompute_movement_modifiers):
		item_inventory.changed.connect(_recompute_movement_modifiers)
	movement_assist.unfallen_started.connect(func(duration: float) -> void: unfallen_started.emit(duration))
	movement_assist.unfallen_ended.connect(func() -> void: unfallen_ended.emit())
	movement_assist.jump_executed.connect(func(source: MudMovementAssist.JumpSource) -> void: jump_executed.emit(source))
	_recompute_movement_modifiers()

func move_direction(dir: Vector2) -> void:
	move_intent = clampf(dir.x, -1.0, 1.0)

func set_move_intent(intent: float) -> void:
	move_intent = clampf(intent, -1.0, 1.0)

func jump() -> void:
	movement_assist.register_jump_input()
	jump_requested = true

func can_jump() -> bool:
	if not character: return false
	return character.is_on_floor() or has_active_coyote_window() or _can_start_wall_jump()

func is_wall_attached() -> bool:
	return wall_action in [&"WallHang", &"WallSlide"]

func is_wall_jump_action() -> bool:
	return wall_action in [&"WallPush", &"WallRelease"]

func cancel_wall_action() -> void:
	_set_wall_action(&"None")

func _set_wall_action(next: StringName) -> void:
	if wall_action == next:
		return
	var previous := wall_action
	wall_action = next
	wall_action_time = 0.0
	wall_action_changed.emit(previous, wall_action)
	if next == &"None" or next == &"WallRelease":
		wall_front_knee_sign = 0.0
		wall_back_knee_sign = 0.0

func _contact_wall_side() -> float:
	if not character or not character.is_on_wall():
		return 0.0
	var normal := character.get_wall_normal()
	if absf(normal.x) < 0.7:
		return 0.0
	return -signf(normal.x)

func _can_hold_wall(side: float) -> bool:
	return side != 0.0 and move_intent * side > wall_input_deadzone and wall_detach_left <= 0.0

func _contact_wall_collider_id(side: float) -> int:
	if side == 0.0 or not character:
		return 0
	for i in character.get_slide_collision_count():
		var collision := character.get_slide_collision(i)
		var normal := collision.get_normal()
		if absf(normal.x) >= 0.7 and is_equal_approx(-signf(normal.x), side):
			var collider := collision.get_collider()
			if is_instance_valid(collider):
				return collider.get_instance_id()
	return 0

func _same_wall_matches(collider_id: int, side: float) -> bool:
	if same_wall_side == 0.0:
		return false
	if collider_id != 0 and same_wall_collider_id != 0:
		return collider_id == same_wall_collider_id
	return is_equal_approx(side, same_wall_side)

func _reset_same_wall_tracking(collider_id := 0, side := 0.0) -> void:
	same_wall_jump_count = 0
	same_wall_collider_id = collider_id
	same_wall_side = side
	same_wall_reset_left = same_wall_reset_time if side != 0.0 else 0.0

func reset_wall_runtime() -> void:
	wall_side = 0.0
	wall_hang_left = 0.0
	wall_regrab_left = 0.0
	wall_coyote_left = 0.0
	wall_detach_left = 0.0
	wall_jump_control_lock_left = 0.0
	wall_detach_grace_left = 0.0
	wall_coyote_side = 0.0
	wall_coyote_collider_id = 0
	pending_wall_jump_kind = &"Standard"
	pending_wall_launch = Vector2.ZERO
	_reset_same_wall_tracking()
	_set_wall_action(&"None")

func detach_wall_pose_for_reaction() -> void:
	wall_side = 0.0
	wall_hang_left = 0.0
	wall_coyote_left = 0.0
	wall_coyote_side = 0.0
	wall_coyote_collider_id = 0
	wall_detach_left = wall_detach_time
	wall_regrab_left = wall_detach_time
	_set_wall_action(&"None")

func _update_wall_memory(delta: float, grounded: bool) -> void:
	wall_regrab_left = maxf(0.0, wall_regrab_left - delta)
	wall_detach_left = maxf(0.0, wall_detach_left - delta)
	wall_jump_control_lock_left = maxf(0.0, wall_jump_control_lock_left - delta)
	if grounded:
		wall_coyote_left = 0.0
		wall_coyote_side = 0.0
		wall_coyote_collider_id = 0
		_reset_same_wall_tracking()
		return

	var side := _contact_wall_side()
	if side != 0.0 and wall_detach_left <= 0.0:
		var collider_id := _contact_wall_collider_id(side)
		wall_coyote_left = wall_coyote_time
		wall_coyote_side = side
		wall_coyote_collider_id = collider_id
		if same_wall_side == 0.0 or not _same_wall_matches(collider_id, side):
			_reset_same_wall_tracking(collider_id, side)
		else:
			same_wall_reset_left = same_wall_reset_time
	else:
		wall_coyote_left = maxf(0.0, wall_coyote_left - delta)
		same_wall_reset_left = maxf(0.0, same_wall_reset_left - delta)
		if same_wall_reset_left <= 0.0:
			_reset_same_wall_tracking()

func _capture_wall_surface(side: float) -> void:
	if not character: return
	for i in character.get_slide_collision_count():
		var collision := character.get_slide_collision(i)
		var normal := collision.get_normal()
		if absf(normal.x) >= 0.7 and is_equal_approx(-signf(normal.x), side):
			wall_surface_x = collision.get_position().x
			return
	if is_inf(wall_surface_x):
		wall_surface_x = character.global_position.x + side * 10.0

func wall_plane_local_x() -> float:
	if wall_side == 0.0 or is_inf(wall_surface_x) or not character:
		return 10.0
	var wall_global := Vector2(wall_surface_x, character.global_position.y)
	var visual: Node2D = character.get_node_or_null("Visual") as Node2D
	if visual:
		return visual.to_local(wall_global).x
	return character.to_local(wall_global).x

func _enter_wall_hang(side: float) -> void:
	wall_side = side
	facing = side
	_capture_wall_surface(side)
	if character:
		wall_hand_anchor_y = character.global_position.y - 51.0
		wall_foot_anchor_y = character.global_position.y - 22.0
		character.velocity.y = 0.0
	wall_slide_scrape_offset = 0.0
	wall_hang_left = wall_hang_duration
	_set_wall_action(&"WallHang")

func _update_wall_before_move(delta: float) -> void:
	wall_action_time += delta
	if not character: return
	if character.is_on_floor():
		wall_side = 0.0
		wall_hang_left = 0.0
		_set_wall_action(&"None")
		return
	if wall_action == &"WallPush":
		character.velocity = Vector2(wall_side * wall_stick_speed, 0.0)
		if wall_action_time >= wall_push_duration:
			var launch := pending_wall_launch
			character.velocity = launch
			wall_detach_left = wall_detach_time
			wall_regrab_left = wall_detach_time
			wall_jump_control_lock_left = wall_jump_control_lock_time
			_set_wall_action(&"WallRelease")
			wall_jumped.emit(launch)
		return
	if wall_action == &"WallRelease":
		if wall_action_time >= wall_release_duration:
			_set_wall_action(&"None")
		return

	var side := _contact_wall_side()
	var wants_away := side != 0.0 and move_intent * side < -wall_input_deadzone
	if is_wall_attached() and wants_away:
		wall_detach_grace_left += delta
	else:
		wall_detach_grace_left = 0.0
	var within_detach_grace := is_wall_attached() and wants_away and wall_detach_grace_left < wall_detach_grace
	if not _can_hold_wall(side) and not within_detach_grace:
		if is_wall_attached():
			_set_wall_action(&"None")
		return
	if not is_wall_attached():
		if character.velocity.y >= -wall_grab_upward_limit:
			_enter_wall_hang(side)
		else:
			return

	wall_side = side
	_capture_wall_surface(side)
	facing = side
	character.velocity.x = wall_side * wall_stick_speed
	if wall_action == &"WallHang":
		wall_hang_left = maxf(0.0, wall_hang_left - delta)
		character.velocity.y = 0.0
		if wall_hang_left <= 0.0:
			_set_wall_action(&"WallSlide")
	elif wall_action == &"WallSlide":
		var scrape_cycle := fmod(wall_action_time, 0.18) / 0.18
		var friction_scale := 0.28 if scrape_cycle < 0.16 else lerpf(0.78, 1.0, scrape_cycle)
		character.velocity.y = minf(character.velocity.y, wall_slide_speed * friction_scale)
		wall_hand_anchor_y += character.velocity.y * delta * 0.24
		wall_hand_anchor_y = maxf(wall_hand_anchor_y, character.global_position.y - 58.0)
		wall_slide_scrape_offset = sin(wall_action_time * 21.0) * 1.0

func _update_wall_after_move() -> void:
	if not character: return
	if character.is_on_floor():
		wall_side = 0.0
		wall_hang_left = 0.0
		_set_wall_action(&"None")
		return
	if is_wall_attached() or is_wall_jump_action():
		return
	var side := _contact_wall_side()
	if _can_hold_wall(side) and character.velocity.y >= -wall_grab_upward_limit:
		_enter_wall_hang(side)

func _can_start_wall_jump() -> bool:
	return wall_detach_left <= 0.0 and (is_wall_attached() or wall_coyote_left > 0.0)

func request_wall_jump() -> bool:
	if not _can_start_wall_jump() or not character:
		return false
	var launch_side := wall_side if is_wall_attached() and wall_side != 0.0 else wall_coyote_side
	if launch_side == 0.0:
		return false
	var collider_id := _contact_wall_collider_id(launch_side)
	if collider_id == 0:
		collider_id = wall_coyote_collider_id
	if same_wall_side == 0.0 or not _same_wall_matches(collider_id, launch_side):
		_reset_same_wall_tracking(collider_id, launch_side)

	var input_relation := move_intent * launch_side
	wall_side = launch_side
	facing = launch_side
	if input_relation > wall_input_deadzone:
		pending_wall_jump_kind = &"Climb"
		var decay := 1.0
		if not wall_climb_decay.is_empty():
			var decay_index := mini(same_wall_jump_count, wall_climb_decay.size() - 1)
			decay = wall_climb_decay[decay_index]
		pending_wall_launch = Vector2(-launch_side * wall_climb_detach_velocity, -wall_climb_jump_velocity * decay)
		same_wall_jump_count += 1
	elif input_relation < -wall_input_deadzone:
		pending_wall_jump_kind = &"Kick"
		pending_wall_launch = Vector2(-launch_side * wall_kick_horizontal_velocity, -wall_kick_velocity)
	else:
		pending_wall_jump_kind = &"Standard"
		pending_wall_launch = Vector2(-launch_side * wall_jump_horizontal_speed, -wall_jump_vertical_speed)
	same_wall_reset_left = same_wall_reset_time
	wall_coyote_left = 0.0
	movement_assist.suppress_ground_departure()
	movement_assist.jump_buffer_remaining = 0.0
	character.velocity = Vector2(wall_side * wall_stick_speed, 0.0)
	wall_hang_left = 0.0
	_set_wall_action(&"WallPush")
	jump_phase = &"WallPush"
	air_time = 0.0
	return true

func _recompute_movement_modifiers() -> void:
	movement_assist.apply_modifiers(item_inventory.aggregate_movement_modifiers())

func obtain_item(item: CoyoteItem) -> void:
	item_inventory.obtain(item)

func remove_item(item_id: StringName) -> void:
	item_inventory.remove(item_id)

func obtain_content_item(content_id: StringName) -> bool:
	if not has_node("/root/ContentRegistry"): return false
	var registry := get_node("/root/ContentRegistry")
	var definition: ContentDefinition = registry.call("get_content", content_id) as ContentDefinition
	if definition == null or not definition.resource is CoyoteItem: return false
	obtain_item(definition.resource as CoyoteItem)
	return true

func is_unfallen() -> bool:
	return movement_assist.is_unfallen()

func has_active_coyote_window() -> bool:
	return movement_assist.has_active_coyote_window()

func get_effective_coyote_time() -> float:
	return movement_assist.get_effective_coyote_time()

func get_effective_jump_buffer_time() -> float:
	return movement_assist.get_effective_jump_buffer_time()

func _is_coyote_source(source: MudMovementAssist.JumpSource) -> bool:
	return source in [MudMovementAssist.JumpSource.COYOTE, MudMovementAssist.JumpSource.BUFFERED_COYOTE]

func perform_jump(source: MudMovementAssist.JumpSource) -> void:
	if not character: return
	var is_coyote := _is_coyote_source(source)
	var vertical_multiplier := movement_assist.coyote_vertical_jump_multiplier if is_coyote else 1.0
	character.velocity.y = jump_velocity * vertical_multiplier
	if is_coyote and absf(character.velocity.x) > 0.01:
		var launch_cap := move_speed * movement_assist.coyote_horizontal_jump_multiplier
		character.velocity.x = clampf(character.velocity.x * movement_assist.coyote_horizontal_jump_multiplier, -launch_cap, launch_cap)
	jump_squat_left = 0.0
	landing_left = 0.0
	air_time = 0.0
	pending_jump_source = MudMovementAssist.JumpSource.NONE
	movement_assist.report_jump_executed(source)

func _try_start_assisted_jump(grounded: bool, current_state: StringName) -> bool:
	var source := movement_assist.resolve_jump_source(grounded)
	if source == MudMovementAssist.JumpSource.NONE:
		return false
	movement_assist.consume_jump(source)
	if source == MudMovementAssist.JumpSource.GROUND:
		pending_jump_source = source
		jump_squat_left = jump_squat_duration
		landing_left = 0.0
	else:
		perform_jump(source)
	return true

func reset_runtime(grounded: bool = false) -> void:
	reset_wall_runtime()
	air_time = 0.0
	last_air_velocity_y = 0.0
	jump_phase = &"Grounded"
	jump_squat_left = 0.0
	landing_left = 0.0
	landing_animation = &""
	grounded_resume_phase = 0.0
	pending_jump_source = MudMovementAssist.JumpSource.NONE
	move_intent = 0.0
	jump_requested = false
	movement_assist.reset(grounded)

func physics_step(delta: float, atk_mult: float, allow_coyote_departure: bool, is_attacking_or_blocking: bool, current_state: StringName) -> void:
	if not character: return
	var grounded := character.is_on_floor()
	movement_assist.observe_grounded(grounded, allow_coyote_departure and wall_action == &"None")
	_update_wall_memory(delta, grounded)
	landing_left = maxf(0.0, landing_left - delta)

	var horizontal_acceleration := acceleration * (wall_jump_air_control if wall_jump_control_lock_left > 0.0 else 1.0)
	character.velocity.x = move_toward(character.velocity.x, move_intent * move_speed * atk_mult, horizontal_acceleration * delta)
	if move_intent != 0 and not is_attacking_or_blocking and wall_action == &"None":
		facing = signf(move_intent)
	if not grounded:
		character.velocity.y += gravity * movement_assist.get_gravity_multiplier() * delta

	var wall_jump_req := jump_requested or movement_assist.has_buffered_jump()
	var started_wall_jump := false
	if wall_jump_req:
		started_wall_jump = request_wall_jump()
	_update_wall_before_move(delta)
	if not started_wall_jump and jump_squat_left <= 0:
		_try_start_assisted_jump(grounded, current_state)
	if jump_squat_left > 0:
		jump_squat_left = maxf(0.0, jump_squat_left - delta)
		if not grounded:
			jump_squat_left = 0.0
		elif jump_squat_left == 0 and pending_jump_source != MudMovementAssist.JumpSource.NONE:
			perform_jump(pending_jump_source)
	movement_assist.advance(delta, grounded, allow_coyote_departure)
	if not grounded or character.velocity.y < 0:
		last_air_velocity_y = character.velocity.y
	jump_requested = false

	character.move_and_slide()
	_update_wall_after_move()

	var grounded_after_move := character.is_on_floor()
	movement_assist.observe_grounded(grounded_after_move, allow_coyote_departure and wall_action == &"None")
	if not grounded and grounded_after_move:
		_try_start_assisted_jump(true, current_state)
	movement_assist.finish_step()
	land_time = maxf(0.0, land_time - delta)

	if not grounded and character.is_on_floor():
		if air_time >= minimum_landing_air_time and last_air_velocity_y >= soft_landing_speed:
			var hard := last_air_velocity_y >= hard_landing_speed
			jump_phase = &"HardLand" if hard else &"SoftLand"
			landing_animation = StringName("Air/" + String(jump_phase))
			landed.emit(last_air_velocity_y, hard)
		air_time = 0.0
	elif not character.is_on_floor():
		air_time += delta

	# Determine locomotion state
	var next_state: StringName = current_state
	if not character.is_on_floor():
		next_state = &"Jump" if character.velocity.y < 0 else &"Fall"
	elif absf(character.velocity.x) <= 5 and move_intent == 0.0:
		next_state = &"Idle"
	else:
		next_state = &"Walk" if absf(character.velocity.x) <= move_speed * 0.6 else &"Run"

	if next_state != current_movement_state:
		current_movement_state = next_state
		movement_state_changed.emit(current_movement_state)
