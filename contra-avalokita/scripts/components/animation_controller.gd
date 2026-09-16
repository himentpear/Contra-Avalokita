class_name AnimationController
extends Node

signal presentation_reset_requested

const AnimationLayerManagerScript = preload("res://scripts/components/animation/animation_layer_manager.gd")

var provider: AnimationContextProvider
var profile: CharacterAnimationProfile
var binding: AnimationBinding
var layer_manager: AnimationLayerManager

func setup(
	context_provider: AnimationContextProvider,
	animation_profile: CharacterAnimationProfile,
	animation_binding: AnimationBinding
) -> void:
	provider = context_provider
	profile = animation_profile
	binding = animation_binding
	setup_layer_manager()

func setup_layer_manager() -> void:
	layer_manager = get_node_or_null("AnimationLayerManager") as AnimationLayerManager
	if layer_manager == null:
		layer_manager = AnimationLayerManagerScript.new()
		layer_manager.name = "AnimationLayerManager"
		add_child(layer_manager)
	layer_manager.setup(provider, profile, binding)

func update_layers(delta: float) -> void:
	if layer_manager:
		layer_manager.update_layers(delta)

func current_context() -> AnimationContext:
	return layer_manager.refresh_context() if layer_manager != null else AnimationContext.new()

func is_retreating() -> bool:
	return bool(current_context().get_value(&"retreating", false))

func get_state_animation(state_name: StringName) -> StringName:
	var context := current_context()
	context.locomotion_state = state_name
	if state_name != &"Walk" and state_name != &"Run":
		context.tags.erase(&"locomotion_variant")
	return layer_manager.resolve_locomotion(context) if layer_manager != null else state_name

func get_attack_animation() -> StringName:
	var context := current_context()
	return layer_manager.resolve_combat(context) if layer_manager != null else &""

func sync_weapon_animation() -> void:
	presentation_reset_requested.emit()
	var context := current_context()
	if context.locomotion_state in [&"Idle", &"Walk", &"Run", &"Jump", &"Fall"]:
		var target := layer_manager.resolve_locomotion(context)
		_play_preserving_phase(target, 0.12)

## Compatibility playback hook. Gameplay owns the state mutation and passes both
## semantic states after it emits its own state_changed signal.
func transition(previous: StringName, next: StringName) -> void:
	if binding == null or binding.animation_player == null:
		return
	var player := binding.animation_player
	var context := current_context()
	context.locomotion_state = next
	if next != &"Walk" and next != &"Run":
		context.tags.erase(&"locomotion_variant")
	var target := layer_manager.resolve_locomotion(context)
	if (previous == &"Walk" or previous == &"Run") and (next == &"Walk" or next == &"Run"):
		_play_preserving_phase(target, 0.10)
	elif next == &"Idle" and (previous == &"Walk" or previous == &"Run"):
		layer_manager.play(target, 0.09)
	elif next == &"Idle" and (previous == &"Fall" or previous == &"Jump"):
		context.locomotion_state = &"Land"
		context.tags.erase(&"locomotion_variant")
		var land := layer_manager.resolve_locomotion(context)
		if binding.has_animation(land):
			layer_manager.play(land, 0.04)
			player.queue(target)
		else:
			layer_manager.play(target, 0.10)
	else:
		match next:
			&"Idle": layer_manager.play(target, 0.15)
			&"Walk", &"Run": layer_manager.play(target, 0.12)
			&"Jump": layer_manager.play(target, 0.08)
			&"Fall": layer_manager.play(target, 0.10)

func update_jump_animation() -> void:
	if binding == null or binding.animation_player == null or layer_manager == null:
		return
	var context := current_context()
	var clip: StringName = &""
	if context.wall_action != &"None":
		clip = layer_manager.resolve_wall(context)
	elif context.jump_phase != &"Grounded":
		clip = layer_manager.resolve_air(context)

	var player := binding.animation_player
	if clip != &"" and player.current_animation != clip:
		layer_manager.play(clip, 0.025)
	elif clip == &"" and context.locomotion_state in [&"Idle", &"Walk", &"Run"]:
		var locomotion := layer_manager.resolve_locomotion(context)
		if player.current_animation != locomotion or not player.is_playing():
			layer_manager.play(locomotion, 0.09)
			if context.locomotion_state in [&"Walk", &"Run"]:
				var phase := float(context.get_value(&"grounded_resume_phase", 0.0))
				player.seek(phase * player.current_animation_length, true)

func _play_preserving_phase(target: StringName, blend_time: float) -> void:
	if binding == null or binding.animation_player == null:
		return
	var player := binding.animation_player
	if player.current_animation == target:
		return
	var previous_length := player.current_animation_length
	var normalized := player.current_animation_position / maxf(previous_length, 0.001) if previous_length > 0.0 else 0.0
	if layer_manager.play(target, blend_time):
		player.seek(normalized * player.current_animation_length, true)
