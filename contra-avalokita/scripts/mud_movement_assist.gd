class_name MudMovementAssist
extends RefCounted

signal unfallen_started(duration: float)
signal unfallen_ended
signal jump_executed(source: JumpSource)

enum JumpSource {
	NONE,
	GROUND,
	COYOTE,
	BUFFERED_GROUND,
	BUFFERED_COYOTE,
}

var base_coyote_time := 0.10
var base_jump_buffer_time := 0.08
var coyote_time_bonus := 0.0
var jump_buffer_time_bonus := 0.0
var coyote_horizontal_jump_multiplier := 1.0
var coyote_vertical_jump_multiplier := 1.0
var coyote_initial_gravity_multiplier := 1.0
var coyote_initial_gravity_duration := 0.0

var coyote_remaining := 0.0
var jump_buffer_remaining := 0.0
var was_grounded := false
var coyote_available := false
var last_jump_source := JumpSource.NONE
var _jump_registered_this_step := false
var _suppress_next_departure := false

func configure(base_coyote: float, base_buffer: float) -> void:
	base_coyote_time = base_coyote
	base_jump_buffer_time = base_buffer

func apply_modifiers(modifiers: Dictionary) -> void:
	coyote_time_bonus = float(modifiers.get(&"coyote_time_bonus", 0.0))
	jump_buffer_time_bonus = float(modifiers.get(&"jump_buffer_time_bonus", 0.0))
	coyote_horizontal_jump_multiplier = float(modifiers.get(&"coyote_horizontal_jump_multiplier", 1.0))
	coyote_vertical_jump_multiplier = float(modifiers.get(&"coyote_vertical_jump_multiplier", 1.0))
	coyote_initial_gravity_multiplier = float(modifiers.get(&"coyote_initial_gravity_multiplier", 1.0))
	coyote_initial_gravity_duration = float(modifiers.get(&"coyote_initial_gravity_duration", 0.0))
	if coyote_available:
		coyote_remaining = minf(coyote_remaining, get_effective_coyote_time())
	jump_buffer_remaining = minf(jump_buffer_remaining, get_effective_jump_buffer_time())

func get_effective_coyote_time() -> float:
	return maxf(0.0, base_coyote_time + coyote_time_bonus)

func get_effective_jump_buffer_time() -> float:
	return maxf(0.0, base_jump_buffer_time + jump_buffer_time_bonus)

func get_coyote_remaining() -> float:
	return coyote_remaining

func get_coyote_progress() -> float:
	return coyote_remaining / maxf(get_effective_coyote_time(), 0.0001) if coyote_available else 0.0

func has_active_coyote_window() -> bool:
	return coyote_available and coyote_remaining > 0.0

func is_unfallen() -> bool:
	return has_active_coyote_window() and not was_grounded

func register_jump_input() -> void:
	jump_buffer_remaining = get_effective_jump_buffer_time()
	_jump_registered_this_step = true

func has_buffered_jump() -> bool:
	return jump_buffer_remaining > 0.0

func resolve_jump_source(grounded: bool) -> JumpSource:
	if not has_buffered_jump():
		return JumpSource.NONE
	if grounded:
		return JumpSource.GROUND if _jump_registered_this_step else JumpSource.BUFFERED_GROUND
	if has_active_coyote_window():
		return JumpSource.COYOTE if _jump_registered_this_step else JumpSource.BUFFERED_COYOTE
	return JumpSource.NONE

func consume_jump(source: JumpSource) -> void:
	if source == JumpSource.NONE:
		return
	jump_buffer_remaining = 0.0
	last_jump_source = source
	_suppress_next_departure = true
	_end_unfallen()

func report_jump_executed(source: JumpSource) -> void:
	last_jump_source = source
	jump_executed.emit(source)

func suppress_ground_departure() -> void:
	_suppress_next_departure = true
	_end_unfallen()

func advance(delta: float, grounded: bool, allow_coyote_departure := true) -> void:
	observe_grounded(grounded, allow_coyote_departure)
	if jump_buffer_remaining > 0.0:
		jump_buffer_remaining = maxf(0.0, jump_buffer_remaining - delta)
	if coyote_available:
		coyote_remaining = maxf(0.0, coyote_remaining - delta)
		if coyote_remaining <= 0.0:
			_end_unfallen()

func finish_step() -> void:
	_jump_registered_this_step = false

func observe_grounded(grounded: bool, allow_coyote_departure := true) -> void:
	if was_grounded and not grounded:
		if _suppress_next_departure:
			_suppress_next_departure = false
		elif allow_coyote_departure:
			coyote_available = get_effective_coyote_time() > 0.0
			coyote_remaining = get_effective_coyote_time()
			if coyote_available:
				unfallen_started.emit(coyote_remaining)
	elif not was_grounded and grounded:
		_end_unfallen()
	was_grounded = grounded

func get_gravity_multiplier() -> float:
	if not is_unfallen() or coyote_initial_gravity_duration <= 0.0:
		return 1.0
	var elapsed := get_effective_coyote_time() - coyote_remaining
	return coyote_initial_gravity_multiplier if elapsed <= coyote_initial_gravity_duration else 1.0

func reset(grounded := false) -> void:
	coyote_remaining = 0.0
	jump_buffer_remaining = 0.0
	was_grounded = grounded
	coyote_available = false
	last_jump_source = JumpSource.NONE
	_jump_registered_this_step = false
	_suppress_next_departure = false

func source_name(source: JumpSource = last_jump_source) -> StringName:
	return JumpSource.keys()[source]

func _end_unfallen() -> void:
	var was_active := coyote_available
	coyote_available = false
	coyote_remaining = 0.0
	if was_active:
		unfallen_ended.emit()
