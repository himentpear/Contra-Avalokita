class_name AnimationContext
extends RefCounted

## A renderer-free snapshot of gameplay meaning for the animation pipeline.
## Keep engine objects and character/component references out of this type.
var locomotion_state: StringName = &"Idle"
var action_state: StringName = &"None"
var reaction_state: StringName = &"None"

var velocity := Vector2.ZERO
var grounded := false
var facing := 1.0
var armed := false
var movement_intensity := 0.0

var jump_phase: StringName = &"Grounded"
var wall_action: StringName = &"None"

var attack_stage := 0
var weapon_class: StringName = &"unarmed"

var reaction_direction := Vector2.ZERO
var reaction_intensity := 0.0

var tags: Dictionary = {}

func set_value(key: StringName, value: Variant) -> void:
	tags[key] = value

func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return tags.get(key, default_value)
