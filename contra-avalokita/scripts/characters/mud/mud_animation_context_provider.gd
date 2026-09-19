class_name MudAnimationContextProvider
extends AnimationContextProvider

var body: CharacterBody2D
var movement_component: Node
var state_component: Node
var combat_component: Node
var equipment_controller: Node

## Test seam for a snapshot that has not entered the physics tree.
var grounded_override: Variant = null

func configure(
	p_body: CharacterBody2D,
	p_movement_component: Node,
	p_state_component: Node,
	p_combat_component: Node,
	p_equipment_controller: Node
) -> MudAnimationContextProvider:
	body = p_body
	movement_component = p_movement_component
	state_component = p_state_component
	combat_component = p_combat_component
	equipment_controller = p_equipment_controller
	return self

func build_context() -> AnimationContext:
	var context := AnimationContext.new()
	context.locomotion_state = _name_from(state_component, &"locomotion_state", &"Idle")
	context.action_state = _name_from(state_component, &"action_state", &"None")
	context.reaction_state = _name_from(state_component, &"reaction_state", &"None")
	context.velocity = body.velocity if is_instance_valid(body) else Vector2.ZERO
	context.grounded = bool(grounded_override) if grounded_override != null else (body.is_on_floor() if is_instance_valid(body) else false)
	context.facing = _float_from(movement_component, &"facing", 1.0)
	context.armed = _is_armed()
	context.weapon_class = _weapon_class() if context.armed else &"unarmed"
	# Attack/guard semantics take ownership immediately, before the visual sync has
	# had a chance to reparent the weapon on the first action frame.
	var action_needs_weapon := context.action_state.begins_with("Attack") or context.action_state == &"Block"
	if context.armed and not action_needs_weapon and is_instance_valid(equipment_controller) and equipment_controller.has_method("is_weapon_in_hand") and not bool(equipment_controller.call("is_weapon_in_hand")):
		context.tags[&"locomotion_weapon_class"] = &"unarmed"
	context.attack_stage = _int_from(combat_component, &"combo_stage", 0)
	var raw_wall_action := _name_from(movement_component, &"wall_action", &"None")
	context.wall_action = _semantic_wall_action(raw_wall_action)
	context.jump_phase = _derive_jump_phase(context)
	context.reaction_direction = _vector_from(combat_component, &"reaction_direction", Vector2.ZERO)
	context.reaction_intensity = _float_from(combat_component, &"reaction_intensity", 0.0)

	var move_speed := maxf(_float_from(movement_component, &"move_speed", 1.0), 0.001)
	context.movement_intensity = clampf(absf(context.velocity.x) / move_speed, 0.0, 1.0)
	context.tags[&"grounded_resume_phase"] = _float_from(movement_component, &"grounded_resume_phase", 0.0)
	if _is_retreating(context):
		context.tags[&"retreating"] = true
		context.tags[&"locomotion_variant"] = &"Backstep"

	# jump_phase is gameplay-readable state in the existing Mud compatibility API.
	if is_instance_valid(movement_component):
		movement_component.set("jump_phase", raw_wall_action if raw_wall_action != &"None" else context.jump_phase)
	return context

func _derive_jump_phase(context: AnimationContext) -> StringName:
	if context.wall_action != &"None":
		return context.wall_action
	if _float_from(movement_component, &"jump_squat_left", 0.0) > 0.0:
		return &"JumpSquat"
	if not context.grounded:
		var air_time := _float_from(movement_component, &"air_time", 0.0)
		var takeoff_duration := _float_from(movement_component, &"takeoff_duration", 0.075)
		var apex_threshold := _float_from(movement_component, &"apex_threshold", 35.0)
		if context.velocity.y < 0.0 and air_time < takeoff_duration:
			return &"Takeoff"
		if context.velocity.y < -apex_threshold:
			return &"Rise"
		if absf(context.velocity.y) <= apex_threshold:
			return &"Apex"
		return &"Fall"
	var landing_left := _float_from(movement_component, &"landing_left", 0.0)
	if landing_left > 0.0:
		var recovery_duration := _float_from(movement_component, &"landing_recovery_duration", 0.07)
		if landing_left <= recovery_duration:
			return &"Recovery"
		return _name_from(movement_component, &"jump_phase", &"SoftLand")
	return &"Grounded"

func _semantic_wall_action(action: StringName) -> StringName:
	match action:
		&"WallHang": return &"Hang"
		&"WallSlide": return &"Slide"
		&"WallPush": return &"Push"
		&"WallRelease": return &"Release"
	return action

func _is_retreating(context: AnimationContext) -> bool:
	if not context.action_state.begins_with("Attack") or not context.grounded:
		return false
	var move_intent := _float_from(movement_component, &"move_intent", 0.0)
	if move_intent != 0.0 and context.facing * move_intent < -0.01:
		return true
	return absf(move_intent) <= 0.01 and context.facing * context.velocity.x < -5.0

func _is_armed() -> bool:
	return is_instance_valid(equipment_controller) and equipment_controller.has_method("is_armed") and bool(equipment_controller.call("is_armed"))

func _weapon_class() -> StringName:
	if not is_instance_valid(equipment_controller):
		return &"unarmed"
	var current: Variant = equipment_controller.get("current")
	if not is_instance_valid(current):
		return &"unarmed"
	var value: Variant = current.get("weapon_class")
	return StringName(value) if value != null else &"armed"

func _name_from(source: Object, property: StringName, default_value: StringName) -> StringName:
	var value: Variant = _value_from(source, property, default_value)
	return StringName(value)

func _float_from(source: Object, property: StringName, default_value: float) -> float:
	return float(_value_from(source, property, default_value))

func _int_from(source: Object, property: StringName, default_value: int) -> int:
	return int(_value_from(source, property, default_value))

func _vector_from(source: Object, property: StringName, default_value: Vector2) -> Vector2:
	var value: Variant = _value_from(source, property, default_value)
	return value as Vector2

func _value_from(source: Object, property: StringName, default_value: Variant) -> Variant:
	if not is_instance_valid(source):
		return default_value
	# Object.get returns null for a missing property. Scanning get_property_list()
	# for every field made each NPC's per-frame animation snapshot very costly.
	var value: Variant = source.get(property)
	return default_value if value == null else value
