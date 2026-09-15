class_name AnimationContext
extends RefCounted

var character: Node
var animation_player: AnimationPlayer
var skeleton: Skeleton2D

var locomotion_state: StringName = &"Idle"
var action_state: StringName = &"None"
var reaction_state: StringName = &"None"
var velocity := Vector2.ZERO
var grounded := false
var facing := 1.0
var armed := false

var values: Dictionary = {}

func bind(
	p_character: Node,
	p_animation_player: AnimationPlayer = null,
	p_skeleton: Skeleton2D = null
) -> AnimationContext:
	character = p_character
	animation_player = p_animation_player
	skeleton = p_skeleton
	refresh()
	return self

func refresh() -> void:
	locomotion_state = &"Idle"
	action_state = &"None"
	reaction_state = &"None"
	velocity = Vector2.ZERO
	grounded = false
	facing = 1.0
	armed = false
	if not is_instance_valid(character):
		return

	if "state" in character:
		locomotion_state = StringName(character.get("state"))
	if "action_state" in character:
		action_state = StringName(character.get("action_state"))
	if "reaction_state" in character:
		reaction_state = StringName(character.get("reaction_state"))
	if character is CharacterBody2D:
		velocity = (character as CharacterBody2D).velocity
		grounded = (character as CharacterBody2D).is_on_floor()
	if "facing" in character:
		facing = float(character.get("facing"))
	armed = bool(character.call("is_armed")) if character.has_method("is_armed") else false

func set_value(key: StringName, value: Variant) -> void:
	values[key] = value

func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return values.get(key, default_value)
