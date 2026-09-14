class_name VFXRouter
extends Node2D

## Local sockets attached to character skeletons/visuals
enum LocalChannel {
	BEHIND,
	BODY,
	FRONT,
}

## World-space runtime FX containers that remain in world space after spawning
enum WorldChannel {
	WORLD_TRANSIENT,
	PROJECTILE,
	DETACHED_CHARACTER,
	COMBAT,
	DYNAMIC_LIGHT,
}

## Legacy unified channel enum preserved for backwards compatibility
enum Channel {
	CHARACTER_BEHIND,
	CHARACTER_BODY,
	CHARACTER_FRONT,
	COMBAT,
	PROJECTILE,
	WORLD_TRANSIENT,
	DETACHED_CHARACTER,
	DYNAMIC_LIGHT,
}

@export_group("World Runtime Containers")
@export var world_transient_fx: Node2D
@export var projectile_fx: Node2D
@export var detached_character_fx: Node2D
@export var combat_fx: Node2D
@export var dynamic_lights: Node2D

func _ready() -> void:
	if not world_transient_fx: world_transient_fx = get_node_or_null("WorldTransientFX")
	if not projectile_fx: projectile_fx = get_node_or_null("ProjectileFX")
	if not detached_character_fx: detached_character_fx = get_node_or_null("DetachedCharacterFX")
	if not combat_fx: combat_fx = get_node_or_null("CombatFX")
	if not dynamic_lights: dynamic_lights = get_node_or_null("../World/Lighting/DynamicLights")

## Spawns an effect rigidly attached to a character's local visual hierarchy.
## The effect inherits the character's transform and movement automatically.
func spawn_character_fx(character: Node2D, effect: Node2D, local_channel: LocalChannel, local_offset: Vector2 = Vector2.ZERO) -> Node2D:
	if not effect: return null
	var socket: Node2D = null
	if character:
		if character.has_method("get_local_fx_socket"):
			match local_channel:
				LocalChannel.BEHIND: socket = character.call("get_local_fx_socket", &"Behind")
				LocalChannel.BODY: socket = character.call("get_local_fx_socket", &"Body")
				LocalChannel.FRONT: socket = character.call("get_local_fx_socket", &"Front")
		if not socket:
			var visual := character.get_node_or_null("Visual")
			if visual:
				match local_channel:
					LocalChannel.BEHIND: socket = visual.get_node_or_null("LocalFXBehind")
					LocalChannel.BODY: socket = visual.get_node_or_null("LocalFXBody")
					LocalChannel.FRONT: socket = visual.get_node_or_null("LocalFXFront")
			if not socket:
				socket = character
	if not socket:
		socket = self

	socket.add_child(effect)
	effect.position = local_offset
	return effect

## Spawns a world-space runtime effect that remains stationary or moves independently of actors.
func spawn_world_fx(effect: Node2D, world_channel: WorldChannel, global_pos: Vector2) -> Node2D:
	if not effect: return null
	var target_parent: Node2D = null
	match world_channel:
		WorldChannel.WORLD_TRANSIENT:
			target_parent = world_transient_fx
		WorldChannel.PROJECTILE:
			target_parent = projectile_fx
		WorldChannel.DETACHED_CHARACTER:
			target_parent = detached_character_fx
		WorldChannel.COMBAT:
			target_parent = combat_fx
		WorldChannel.DYNAMIC_LIGHT:
			target_parent = dynamic_lights
	if not target_parent:
		target_parent = self

	target_parent.add_child(effect)
	effect.global_position = global_pos
	return effect

## Legacy routing function preserving compatibility
func spawn_fx(effect: Node2D, channel: Channel, world_position: Vector2, parent_to_target: Node2D = null) -> Node2D:
	if not effect: return null
	match channel:
		Channel.CHARACTER_BEHIND:
			if parent_to_target:
				return spawn_character_fx(parent_to_target, effect, LocalChannel.BEHIND)
			return spawn_world_fx(effect, WorldChannel.DETACHED_CHARACTER, world_position)
		Channel.CHARACTER_BODY:
			if parent_to_target:
				return spawn_character_fx(parent_to_target, effect, LocalChannel.BODY)
			return spawn_world_fx(effect, WorldChannel.DETACHED_CHARACTER, world_position)
		Channel.CHARACTER_FRONT:
			if parent_to_target:
				return spawn_character_fx(parent_to_target, effect, LocalChannel.FRONT)
			return spawn_world_fx(effect, WorldChannel.DETACHED_CHARACTER, world_position)
		Channel.COMBAT:
			return spawn_world_fx(effect, WorldChannel.COMBAT, world_position)
		Channel.PROJECTILE:
			return spawn_world_fx(effect, WorldChannel.PROJECTILE, world_position)
		Channel.WORLD_TRANSIENT:
			return spawn_world_fx(effect, WorldChannel.WORLD_TRANSIENT, world_position)
		Channel.DETACHED_CHARACTER:
			return spawn_world_fx(effect, WorldChannel.DETACHED_CHARACTER, world_position)
		Channel.DYNAMIC_LIGHT:
			return spawn_world_fx(effect, WorldChannel.DYNAMIC_LIGHT, world_position)
	return spawn_world_fx(effect, WorldChannel.WORLD_TRANSIENT, world_position)
