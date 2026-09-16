class_name CharacterAnimationProfile
extends Resource

@export var character_id: StringName
@export var rig_id: StringName

@export var locomotion: Dictionary = {}
@export var air: Dictionary = {}
@export var wall: Dictionary = {}
@export var combat: Dictionary = {}
@export var reaction: Dictionary = {}

@export var fallback_animation: StringName = &"Idle"

func resolve_locomotion(context: AnimationContext) -> StringName:
	var action: StringName = context.get_value(&"locomotion_variant", context.locomotion_state)
	var locomotion_weapon_class: StringName = context.get_value(&"locomotion_weapon_class", context.weapon_class)
	var qualified := StringName("%s.%s" % [action, locomotion_weapon_class])
	return _resolve(locomotion, qualified, action)

func resolve_air(context: AnimationContext) -> StringName:
	return _resolve(air, context.jump_phase)

func resolve_wall(context: AnimationContext) -> StringName:
	return _resolve(wall, context.wall_action)

func resolve_combat(context: AnimationContext) -> StringName:
	var action := StringName("%s.attack.%d" % [context.weapon_class, context.attack_stage])
	return _resolve(combat, action)

func resolve_reaction(context: AnimationContext) -> StringName:
	return _resolve(reaction, context.reaction_state)

func resolve(category: StringName, action: StringName) -> StringName:
	match category:
		&"locomotion": return _resolve(locomotion, action)
		&"air": return _resolve(air, action)
		&"wall": return _resolve(wall, action)
		&"combat": return _resolve(combat, action)
		&"reaction": return _resolve(reaction, action)
	return fallback_animation

func _resolve(mapping: Dictionary, key: StringName, fallback_key: StringName = &"") -> StringName:
	if mapping.has(key):
		return StringName(mapping[key])
	var string_key := String(key)
	if mapping.has(string_key):
		return StringName(mapping[string_key])
	if fallback_key != &"" and fallback_key != key:
		if mapping.has(fallback_key):
			return StringName(mapping[fallback_key])
		var fallback_string := String(fallback_key)
		if mapping.has(fallback_string):
			return StringName(mapping[fallback_string])
	return fallback_animation
