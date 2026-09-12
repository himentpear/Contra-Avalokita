class_name MudDeathController
extends Node
## Reference-driven hit-freeze, airborne fall silhouette and SDF dissolution.

signal death_started
signal collapsed_impact
signal death_finished
signal rise_finished

enum EyeDeathMode {
	SINK_AND_FADE,
	INSTANT_EXTINGUISH,
	MELT_INTO_PUDDLE
}

enum DeathPhase {
	NONE,
	FATAL_PAUSE,
	SUPPORT_LOSS,
	COLLAPSE,
	PUDDLE_SETTLE,
	FINISHED,
	RISING
}

@export_group("Timing")
@export_range(0.8, 1.6) var death_duration := 1.28
@export_range(0.05, 0.20) var pause_ratio := 0.14
@export_range(0.15, 0.35) var support_loss_ratio := 0.28
@export_range(0.25, 0.50) var collapse_ratio := 0.38
@export_range(0.10, 0.30) var settle_ratio := 0.20

@export_group("Deformation")
@export_range(0.5, 2.0) var collapse_intensity := 1.0
@export_range(0.05, 0.5) var torso_squash_ratio := 0.20
@export_range(1.5, 3.5) var puddle_spread_ratio := 1.7
@export_range(0.3, 1.0) var limb_retraction_strength := 0.55

@export_group("Particles")
@export_range(4, 32) var droplet_count := 12
@export_range(8, 96) var ascension_particle_count := 42

@export_group("Features")
@export var eye_death_mode := EyeDeathMode.SINK_AND_FADE
@export var drop_weapon := true
@export var embed_equipment := true

var character: CharacterBody2D
var current_phase := DeathPhase.NONE
var elapsed := 0.0
var death_progress := 0.0
var impact_triggered := false
var weapon_dropped := false
var ascension_triggered := false
var _start_pose: Dictionary = {}

func start_death() -> void:
	if current_phase != DeathPhase.NONE and current_phase != DeathPhase.FINISHED: return
	current_phase = DeathPhase.FATAL_PAUSE
	elapsed = 0.0
	death_progress = 0.0
	impact_triggered = false
	weapon_dropped = false
	ascension_triggered = false
	_capture_start_pose()
	if character and character.death_ascension:
		character.death_ascension.reset()
	death_started.emit()

func start_rise() -> void:
	current_phase = DeathPhase.RISING
	elapsed = death_duration
	death_progress = 1.0
	if character and character.death_ascension:
		character.death_ascension.reset()

func reset() -> void:
	current_phase = DeathPhase.NONE
	elapsed = 0.0
	death_progress = 0.0
	impact_triggered = false
	weapon_dropped = false
	ascension_triggered = false
	_start_pose.clear()
	if character and character.death_ascension:
		character.death_ascension.reset()
	restore_skeleton()

func dissolve_progress() -> float:
	var dissolve_start := pause_ratio + support_loss_ratio
	return clampf((death_progress - dissolve_start) / maxf(1.0 - dissolve_start, 0.001), 0.0, 1.0)

func _capture_start_pose() -> void:
	_start_pose.clear()
	if not character or not character.skeleton:
		return
	for bone in character.skeleton.find_children("*", "Bone2D"):
		if bone is Bone2D:
			_start_pose[bone] = bone.transform

func restore_skeleton() -> void:
	if not character or not character.skeleton: return
	for bone in character.skeleton.find_children("*", "Bone2D"):
		if bone is Bone2D:
			bone.apply_rest()

func update(delta: float) -> void:
	if current_phase == DeathPhase.NONE: return
	if current_phase == DeathPhase.FINISHED: return
	
	if current_phase == DeathPhase.RISING:
		elapsed -= delta * 1.5
		death_progress = clampf(elapsed / maxf(death_duration, 0.001), 0.0, 1.0)
		if death_progress <= 0.0:
			reset()
			rise_finished.emit()
			if character:
				character.state = &"Idle"
				if character.anim_player:
					character.anim_player.play(&"Idle")
			return
		_apply_skeleton_rise(death_progress)
		return
	
	elapsed += delta
	death_progress = clampf(elapsed / maxf(death_duration, 0.001), 0.0, 1.0)
	
	var t_pause := death_duration * pause_ratio
	var t_support := t_pause + death_duration * support_loss_ratio
	var t_collapse := t_support + death_duration * collapse_ratio
	
	var previous_phase := current_phase
	if elapsed < t_pause:
		current_phase = DeathPhase.FATAL_PAUSE
	elif elapsed < t_support:
		current_phase = DeathPhase.SUPPORT_LOSS
	elif elapsed < t_collapse:
		current_phase = DeathPhase.COLLAPSE
	elif elapsed < death_duration:
		current_phase = DeathPhase.PUDDLE_SETTLE
	else:
		current_phase = DeathPhase.FINISHED
		death_finished.emit()

	# Trigger impact particle burst at beginning of Collapse phase
	if current_phase >= DeathPhase.COLLAPSE and not impact_triggered:
		impact_triggered = true
		collapsed_impact.emit()
		if character and character.splatter:
			character.splatter.burst(Vector2.ZERO, droplet_count, character.body_renderer.mud_color)

	# The rising particles are sampled from the exact capsules currently feeding
	# the body SDF, so they detach from the silhouette instead of a box emitter.
	if current_phase >= DeathPhase.COLLAPSE and not ascension_triggered:
		ascension_triggered = true
		if character and character.death_ascension and character.body_renderer:
			character.body_renderer.sync_skeleton(character.skeleton)
			character.death_ascension.begin_from_sdf(
				character.body_renderer,
				character.body_renderer.mud_color,
				ascension_particle_count
			)

	# Trigger weapon drop
	if current_phase >= DeathPhase.COLLAPSE and drop_weapon and not weapon_dropped:
		weapon_dropped = true
		if character and character.weapons:
			character.weapons.drop_weapon_to_ground()

	_apply_skeleton_collapse()

func _apply_skeleton_collapse() -> void:
	if not character or not character.skeleton: return
	var skel: Skeleton2D = character.skeleton
	
	var pelvis: Bone2D = skel.get_node_or_null("Pelvis") as Bone2D
	if not pelvis: return
	var torso: Bone2D = pelvis.get_node_or_null("Torso") as Bone2D
	var head: Bone2D = torso.get_node_or_null("Head") as Bone2D if torso else null
	
	var upper_front: Bone2D = torso.get_node_or_null("UpperArmFront") as Bone2D if torso else null
	var fore_front: Bone2D = upper_front.get_node_or_null("ForearmFront") as Bone2D if upper_front else null
	var upper_back: Bone2D = torso.get_node_or_null("UpperArmBack") as Bone2D if torso else null
	var fore_back: Bone2D = upper_back.get_node_or_null("ForearmBack") as Bone2D if upper_back else null
	var hand_front: Bone2D = fore_front.get_node_or_null("HandFront") as Bone2D if fore_front else null
	var hand_back: Bone2D = fore_back.get_node_or_null("HandBack") as Bone2D if fore_back else null
	
	var thigh_front: Bone2D = pelvis.get_node_or_null("ThighFront") as Bone2D
	var shin_front: Bone2D = thigh_front.get_node_or_null("ShinFront") as Bone2D if thigh_front else null
	var thigh_back: Bone2D = pelvis.get_node_or_null("ThighBack") as Bone2D
	var shin_back: Bone2D = thigh_back.get_node_or_null("ShinBack") as Bone2D if thigh_back else null
	var foot_front: Bone2D = shin_front.get_node_or_null("FootFront") as Bone2D if shin_front else null
	var foot_back: Bone2D = shin_back.get_node_or_null("FootBack") as Bone2D if shin_back else null

	match current_phase:
		DeathPhase.FATAL_PAUSE:
			var p := clampf(elapsed / maxf(death_duration * pause_ratio, 0.001), 0.0, 1.0)
			p = ease(p, -2.0)
			# GIF hurt silhouette: a fast, readable recoil with both arms thrown open.
			_blend_from_start(pelvis, Vector2(0, -33), -0.04, p)
			_blend_from_start(torso, Vector2(0, -22), -0.22, p)
			_blend_from_start(head, Vector2(0, -14), 0.25, p)
			_blend_from_start(upper_front, Vector2(4, 0), -1.05, p)
			_blend_from_start(fore_front, Vector2(0, 12), 0.22, p)
			_blend_from_start(hand_front, Vector2(0, 12), 0.10, p)
			_blend_from_start(upper_back, Vector2(-4, 0), 1.05, p)
			_blend_from_start(fore_back, Vector2(0, 12), -0.22, p)
			_blend_from_start(hand_back, Vector2(0, 12), -0.10, p)
			_blend_from_start(thigh_front, Vector2(2, 0), -0.18, p)
			_blend_from_start(shin_front, Vector2(0, 16), 0.62, p)
			_blend_from_start(foot_front, Vector2(0, 16), -0.18, p)
			_blend_from_start(thigh_back, Vector2(-2, 0), 0.25, p)
			_blend_from_start(shin_back, Vector2(0, 16), -0.55, p)
			_blend_from_start(foot_back, Vector2(0, 16), 0.12, p)
			pelvis.position.x += sin(elapsed * 88.0) * (1.0 - p) * 0.8
		
		DeathPhase.SUPPORT_LOSS:
			var t_pause := death_duration * pause_ratio
			var dur_support := death_duration * support_loss_ratio
			var p := clampf((elapsed - t_pause) / maxf(dur_support, 0.001), 0.0, 1.0)
			p = ease(p, 0.65)
			# GIF fall silhouette: hands lift, torso hangs, knees tuck asymmetrically.
			_blend_pose(pelvis, Vector2(0, -33), -0.04, Vector2(1, -24), 0.06, p)
			_blend_pose(torso, Vector2(0, -22), -0.22, Vector2(0, -19), 0.22, p)
			_blend_pose(head, Vector2(0, -14), 0.25, Vector2(0, -13), -0.18, p)
			_blend_pose(upper_front, Vector2(4, 0), -1.05, Vector2(4, 0), -2.25, p)
			_blend_pose(fore_front, Vector2(0, 12), 0.22, Vector2(0, 12), 0.10, p)
			_blend_pose(hand_front, Vector2(0, 12), 0.10, Vector2(0, 12), -0.16, p)
			_blend_pose(upper_back, Vector2(-4, 0), 1.05, Vector2(-4, 0), 2.25, p)
			_blend_pose(fore_back, Vector2(0, 12), -0.22, Vector2(0, 12), -0.10, p)
			_blend_pose(hand_back, Vector2(0, 12), -0.10, Vector2(0, 12), 0.16, p)
			_blend_pose(thigh_front, Vector2(2, 0), -0.18, Vector2(2, 0), -0.55, p)
			_blend_pose(shin_front, Vector2(0, 16), 0.62, Vector2(0, 16), 1.15, p)
			_blend_pose(foot_front, Vector2(0, 16), -0.18, Vector2(0, 16), -0.45, p)
			_blend_pose(thigh_back, Vector2(-2, 0), 0.25, Vector2(-2, 0), 0.45, p)
			_blend_pose(shin_back, Vector2(0, 16), -0.55, Vector2(0, 16), -0.95, p)
			_blend_pose(foot_back, Vector2(0, 16), 0.12, Vector2(0, 16), 0.35, p)
		
		DeathPhase.COLLAPSE, DeathPhase.PUDDLE_SETTLE, DeathPhase.FINISHED:
			var t_support := death_duration * (pause_ratio + support_loss_ratio)
			var dur_collapse := death_duration * collapse_ratio
			var p := clampf((elapsed - t_support) / maxf(dur_collapse, 0.001), 0.0, 1.0)
			p = ease(p, 0.45)
			var final_pelvis_y := lerpf(-24.0, -5.0, p)
			# Viscous ripple settling at end
			if current_phase == DeathPhase.PUDDLE_SETTLE:
				var ripple := sin((death_progress - 0.77) * 20.0) * exp(-(death_progress - 0.77) * 10.0) * 0.8
				final_pelvis_y += ripple
			_blend_pose(pelvis, Vector2(1, -24), 0.06, Vector2(5, final_pelvis_y), 0.0, p)
			_blend_pose(torso, Vector2(0, -19), 0.22, Vector2(-2, -4), -1.05, p)
			_blend_pose(head, Vector2(0, -13), -0.18, Vector2(0, -10), 0.20, p)
			_blend_pose(upper_front, Vector2(4, 0), -2.25, Vector2(4, 0), -0.35, p)
			_blend_pose(fore_front, Vector2(0, 12), 0.10, Vector2(0, 12), 1.10, p)
			_blend_pose(hand_front, Vector2(0, 12), -0.16, Vector2(0, 12), 0.35, p)
			_blend_pose(upper_back, Vector2(-4, 0), 2.25, Vector2(-4, 0), 1.80, p)
			_blend_pose(fore_back, Vector2(0, 12), -0.10, Vector2(0, 12), -0.75, p)
			_blend_pose(hand_back, Vector2(0, 12), 0.16, Vector2(0, 12), -0.30, p)
			_blend_pose(thigh_front, Vector2(2, 0), -0.55, Vector2(2, 0), -1.20, p)
			_blend_pose(shin_front, Vector2(0, 16), 1.15, Vector2(0, 16), 0.35, p)
			_blend_pose(foot_front, Vector2(0, 16), -0.45, Vector2(0, 16), 0.35, p)
			_blend_pose(thigh_back, Vector2(-2, 0), 0.45, Vector2(-2, 0), 0.95, p)
			_blend_pose(shin_back, Vector2(0, 16), -0.95, Vector2(0, 16), -0.45, p)
			_blend_pose(foot_back, Vector2(0, 16), 0.35, Vector2(0, 16), -0.20, p)

func _blend_from_start(bone: Bone2D, target_position: Vector2, target_rotation: float, weight: float) -> void:
	if not bone:
		return
	var source: Transform2D = _start_pose.get(bone, bone.transform)
	bone.position = source.origin.lerp(target_position, weight)
	bone.rotation = lerp_angle(source.get_rotation(), target_rotation, weight)
	bone.scale = source.get_scale().lerp(Vector2.ONE, weight)

func _blend_pose(bone: Bone2D, from_position: Vector2, from_rotation: float, to_position: Vector2, to_rotation: float, weight: float) -> void:
	if not bone:
		return
	bone.position = from_position.lerp(to_position, weight)
	bone.rotation = lerp_angle(from_rotation, to_rotation, weight)
	bone.scale = Vector2.ONE

func _apply_skeleton_rise(p: float) -> void:
	if not character or not character.skeleton: return
	var skel: Skeleton2D = character.skeleton
	
	var pelvis: Bone2D = skel.get_node_or_null("Pelvis") as Bone2D
	if not pelvis: return
	var torso: Bone2D = pelvis.get_node_or_null("Torso") as Bone2D
	var head: Bone2D = torso.get_node_or_null("Head") as Bone2D if torso else null
	
	var upper_front: Bone2D = torso.get_node_or_null("UpperArmFront") as Bone2D if torso else null
	var fore_front: Bone2D = upper_front.get_node_or_null("ForearmFront") as Bone2D if upper_front else null
	var upper_back: Bone2D = torso.get_node_or_null("UpperArmBack") as Bone2D if torso else null
	var fore_back: Bone2D = upper_back.get_node_or_null("ForearmBack") as Bone2D if upper_back else null
	
	var thigh_front: Bone2D = pelvis.get_node_or_null("ThighFront") as Bone2D
	var shin_front: Bone2D = thigh_front.get_node_or_null("ShinFront") as Bone2D if thigh_front else null
	var thigh_back: Bone2D = pelvis.get_node_or_null("ThighBack") as Bone2D
	var shin_back: Bone2D = thigh_back.get_node_or_null("ShinBack") as Bone2D if thigh_back else null

	pelvis.position = Vector2(0, lerpf(-33.0, -3.0, p))
	if torso:
		torso.position = Vector2(0, lerpf(-22.0, -2.0, p))
		torso.rotation = lerpf(0.0, 0.35, p)
	if head:
		head.position = Vector2(0, lerpf(-14.0, -2.0, p))
		head.rotation = 0.0
	
	if upper_front: upper_front.rotation = lerpf(0.05, 1.57, p)
	if fore_front: fore_front.rotation = lerpf(0.08, 1.57, p)
	if upper_back: upper_back.rotation = lerpf(-0.05, -1.57, p)
	if fore_back: fore_back.rotation = lerpf(0.08, 1.57, p)
	if thigh_front: thigh_front.rotation = lerpf(0.0, -1.57, p)
	if shin_front: shin_front.rotation = lerpf(0.05, 1.57, p)
	if thigh_back: thigh_back.rotation = lerpf(0.0, 1.57, p)
	if shin_back: shin_back.rotation = lerpf(0.05, 1.57, p)
