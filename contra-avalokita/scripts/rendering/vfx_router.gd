class_name VFXRouter
extends Node2D

enum Channel {
	CHARACTER_BEHIND,
	CHARACTER_BODY,
	CHARACTER_FRONT,
	COMBAT,
	PROJECTILE,
	WORLD_TRANSIENT,
	DYNAMIC_LIGHT,
}

@export var character_fx_behind: Node2D
@export var character_fx_body: Node2D
@export var character_fx_front: Node2D
@export var combat_fx: Node2D
@export var projectile_fx: Node2D
@export var world_transient_fx: Node2D
@export var dynamic_lights: Node2D

func _ready() -> void:
	if not character_fx_behind: character_fx_behind = get_node_or_null("CharacterFXBehind")
	if not character_fx_body: character_fx_body = get_node_or_null("CharacterFXBody")
	if not character_fx_front: character_fx_front = get_node_or_null("CharacterFXFront")
	if not combat_fx: combat_fx = get_node_or_null("CombatFX")
	if not projectile_fx: projectile_fx = get_node_or_null("ProjectileFX")
	if not world_transient_fx: world_transient_fx = get_node_or_null("WorldTransientFX")
	if not dynamic_lights: dynamic_lights = get_node_or_null("../World/Lighting/DynamicLights")

func get_channel_node(channel: Channel) -> Node2D:
	match channel:
		Channel.CHARACTER_BEHIND:
			return character_fx_behind
		Channel.CHARACTER_BODY:
			return character_fx_body
		Channel.CHARACTER_FRONT:
			return character_fx_front
		Channel.COMBAT:
			return combat_fx
		Channel.PROJECTILE:
			return projectile_fx
		Channel.WORLD_TRANSIENT:
			return world_transient_fx
		Channel.DYNAMIC_LIGHT:
			return dynamic_lights
	return self

func spawn_fx(effect: Node2D, channel: Channel, world_position: Vector2, parent_to_target: Node2D = null) -> Node2D:
	if not effect: return null
	var target_parent := get_channel_node(channel)
	if parent_to_target and is_instance_valid(parent_to_target):
		target_parent = parent_to_target
	if not target_parent:
		target_parent = self
	
	target_parent.add_child(effect)
	effect.global_position = world_position
	return effect
