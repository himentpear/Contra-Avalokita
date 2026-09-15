class_name AnimationController
extends Node

const AnimationLayerManagerScript = preload("res://scripts/components/animation/animation_layer_manager.gd")

var character: CharacterBody2D
var anim_player: AnimationPlayer
var layer_manager: AnimationLayerManager

func setup(p_character: CharacterBody2D, p_anim_player: AnimationPlayer = null) -> void:
	character = p_character
	if p_anim_player:
		anim_player = p_anim_player
	elif character:
		anim_player = character.get_node_or_null("AnimationPlayer") as AnimationPlayer
	setup_layer_manager()

func setup_layer_manager() -> void:
	layer_manager = get_node_or_null("AnimationLayerManager") as AnimationLayerManager
	if layer_manager == null:
		layer_manager = AnimationLayerManagerScript.new()
		layer_manager.name = "AnimationLayerManager"
		add_child(layer_manager)
	var skeleton := character.get_node_or_null("Visual/PoseRoot/Skeleton2D") as Skeleton2D if character else null
	layer_manager.setup(character, anim_player, skeleton)

func update_layers(delta: float) -> void:
	if layer_manager:
		layer_manager.update_layers(delta)

func is_retreating() -> bool:
	if not character: return false
	var is_atk: bool = character.is_attacking() if character.has_method("is_attacking") else false
	if not is_atk or not character.is_on_floor():
		return false
	var move_intent: float = character.get("move_intent") if "move_intent" in character else 0.0
	var facing: float = character.get("facing") if "facing" in character else 1.0
	if move_intent != 0.0 and facing * move_intent < -0.01:
		return true
	if absf(move_intent) <= 0.01 and facing * character.velocity.x < -5.0:
		return true
	return false

func get_state_animation(state_name: StringName) -> StringName:
	var anim_name := state_name
	if is_retreating() and state_name in [&"Walk", &"Run"]:
		anim_name = &"Backstep"
	var is_armed: bool = character.is_armed() if (character and character.has_method("is_armed")) else true
	if not is_armed:
		var unarmed_name := StringName(String(anim_name) + "_Unarmed")
		if anim_player and anim_player.has_animation(unarmed_name):
			return unarmed_name
	return anim_name

func sync_weapon_animation() -> void:
	if not character: return
	var pose_composer = character.get("pose_composer")
	if is_instance_valid(pose_composer):
		pose_composer.restore_base()
		pose_composer.reset_transient()
	if "impact_accent_offset" in character:
		character.impact_accent_offset = Vector2.ZERO
	var state: StringName = character.state if "state" in character else &"Idle"
	if state in [&"Idle", &"Walk", &"Run", &"Jump", &"Fall"]:
		var target_anim := get_state_animation(state)
		if anim_player and anim_player.current_animation != target_anim:
			var prev_len := anim_player.current_animation_length
			var norm_pos := anim_player.current_animation_position / maxf(prev_len, 0.001) if prev_len > 0 else 0.0
			anim_player.play(target_anim, 0.12)
			var next_len := anim_player.current_animation_length
			anim_player.seek(norm_pos * next_len, true)

func transition(next: StringName) -> void:
	if not character: return
	if next == &"Attack":
		if character.has_method("start_attack"):
			character.start_attack()
		return
	if character.state == next: return
	if character.state == &"Dead" and next != &"Dead": return
	var previous: StringName = character.state
	character.state = next
	if character.has_signal("state_changed"):
		character.state_changed.emit(previous, next)
	if anim_player:
		var target_anim := get_state_animation(next)
		if (previous == &"Walk" or previous == &"Run") and (next == &"Walk" or next == &"Run"):
			if anim_player.current_animation != target_anim:
				var prev_len := anim_player.current_animation_length
				var norm_pos := anim_player.current_animation_position / maxf(prev_len, 0.001) if prev_len > 0 else 0.0
				anim_player.play(target_anim, 0.10)
				var next_len := anim_player.current_animation_length
				anim_player.seek(norm_pos * next_len, true)
		elif next == &"Idle" and (previous == &"Walk" or previous == &"Run"):
			anim_player.play(target_anim, 0.09)
		elif next == &"Idle" and (previous == &"Fall" or previous == &"Jump"):
			var land_anim := get_state_animation(&"Land")
			if anim_player.has_animation(land_anim):
				anim_player.play(land_anim, 0.04)
				anim_player.queue(target_anim)
			else:
				anim_player.play(target_anim, 0.10)
		else:
			match next:
				&"Idle": anim_player.play(target_anim, 0.15)
				&"Walk": anim_player.play(target_anim, 0.12)
				&"Run": anim_player.play(target_anim, 0.12)
				&"Jump": anim_player.play(target_anim, 0.08)
				&"Fall": anim_player.play(target_anim, 0.10)
				&"Dead": pass

func update_jump_animation() -> void:
	if not character: return
	var clip: StringName = &""
	var wall_action: StringName = character.get("wall_action") if "wall_action" in character else &"None"
	var jump_squat_left: float = character.get("jump_squat_left") if "jump_squat_left" in character else 0.0
	var air_time: float = character.get("air_time") if "air_time" in character else 0.0
	var takeoff_duration: float = character.get("takeoff_duration") if "takeoff_duration" in character else 0.075
	var apex_threshold: float = character.get("apex_threshold") if "apex_threshold" in character else 35.0
	var landing_left: float = character.get("landing_left") if "landing_left" in character else 0.0
	var landing_recovery_duration: float = character.get("landing_recovery_duration") if "landing_recovery_duration" in character else 0.07
	var landing_animation: StringName = character.get("landing_animation") if "landing_animation" in character else &""
	var state: StringName = character.get("state") if "state" in character else &"Idle"
	var grounded_resume_phase: float = character.get("grounded_resume_phase") if "grounded_resume_phase" in character else 0.0

	if wall_action != &"None":
		character.jump_phase = wall_action
		match wall_action:
			&"WallHang": clip = &"Wall/Hang"
			&"WallSlide": clip = &"Wall/Slide"
			&"WallPush": clip = &"Wall/Push"
			&"WallRelease": clip = &"Wall/Release"
	elif jump_squat_left > 0:
		character.jump_phase = &"JumpSquat"
	elif not character.is_on_floor():
		if character.velocity.y < 0 and air_time < takeoff_duration:
			character.jump_phase = &"Takeoff"
		elif character.velocity.y < -apex_threshold:
			character.jump_phase = &"Rise"
		elif absf(character.velocity.y) <= apex_threshold:
			character.jump_phase = &"Apex"
		else:
			character.jump_phase = &"Fall"
	elif landing_left > 0:
		character.jump_phase = &"Recovery" if landing_left <= landing_recovery_duration else StringName(String(landing_animation).get_slice("/", 1))
	else:
		character.jump_phase = &"Grounded"

	if character.jump_phase != &"Grounded" and clip == &"":
		clip = StringName("Air/" + String(character.jump_phase))
	if character.is_on_floor() and landing_left > 0 and jump_squat_left <= 0:
		clip = landing_animation

	if not anim_player: return

	if clip != &"" and anim_player.current_animation != clip:
		anim_player.play(clip, 0.025)
	elif clip == &"" and state in [&"Idle", &"Walk", &"Run"] and (anim_player.current_animation != get_state_animation(state) or not anim_player.is_playing()):
		anim_player.play(get_state_animation(state), 0.09)
		if state in [&"Walk", &"Run"]:
			anim_player.seek(grounded_resume_phase * anim_player.current_animation_length, true)
