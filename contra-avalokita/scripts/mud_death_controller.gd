class_name MudDeathController
extends Node
## Manages the 4-phase "collapse into mud" death sequence for MudCharacter.

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
@export_range(0.8, 1.4) var death_duration := 1.1
@export_range(0.05, 0.20) var pause_ratio := 0.12
@export_range(0.15, 0.35) var support_loss_ratio := 0.25
@export_range(0.25, 0.50) var collapse_ratio := 0.40
@export_range(0.10, 0.30) var settle_ratio := 0.23

@export_group("Deformation")
@export_range(0.5, 2.0) var collapse_intensity := 1.0
@export_range(0.05, 0.5) var torso_squash_ratio := 0.20
@export_range(1.5, 3.5) var puddle_spread_ratio := 2.4
@export_range(0.5, 1.0) var limb_retraction_strength := 0.85

@export_group("Particles")
@export_range(4, 32) var droplet_count := 16

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

func start_death() -> void:
	if current_phase != DeathPhase.NONE and current_phase != DeathPhase.FINISHED: return
	current_phase = DeathPhase.FATAL_PAUSE
	elapsed = 0.0
	death_progress = 0.0
	impact_triggered = false
	weapon_dropped = false
	death_started.emit()

func start_rise() -> void:
	current_phase = DeathPhase.RISING
	elapsed = death_duration
	death_progress = 1.0

func reset() -> void:
	current_phase = DeathPhase.NONE
	elapsed = 0.0
	death_progress = 0.0
	impact_triggered = false
	weapon_dropped = false
	restore_skeleton()

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
	
	var thigh_front: Bone2D = pelvis.get_node_or_null("ThighFront") as Bone2D
	var shin_front: Bone2D = thigh_front.get_node_or_null("ShinFront") as Bone2D if thigh_front else null
	var thigh_back: Bone2D = pelvis.get_node_or_null("ThighBack") as Bone2D
	var shin_back: Bone2D = thigh_back.get_node_or_null("ShinBack") as Bone2D if thigh_back else null

	match current_phase:
		DeathPhase.FATAL_PAUSE:
			# High frequency micro-jitter (shock before collapse)
			var jitter := sin(elapsed * 80.0) * 1.0
			pelvis.position.x = jitter
		
		DeathPhase.SUPPORT_LOSS:
			var t_pause := death_duration * pause_ratio
			var dur_support := death_duration * support_loss_ratio
			var p := clampf((elapsed - t_pause) / maxf(dur_support, 0.001), 0.0, 1.0)
			p = ease(p, 0.5) # Acceleration into softening
			
			# Pelvis begins sinking
			pelvis.position = Vector2(0, lerpf(-33.0, -18.0, p))
			# Torso compresses and droops forward
			if torso:
				torso.position = Vector2(0, lerpf(-22.0, -12.0, p))
				torso.rotation = lerpf(0.0, 0.35, p)
			if head:
				head.position = Vector2(0, lerpf(-14.0, -8.0, p))
				head.rotation = lerpf(0.0, -0.25, p)
			# Arms slump
			if upper_front:
				upper_front.rotation = lerpf(0.0, 0.6, p)
			if fore_front:
				fore_front.rotation = lerpf(0.0, 0.8, p)
			if upper_back:
				upper_back.rotation = lerpf(0.0, -0.4, p)
			if fore_back:
				fore_back.rotation = lerpf(0.0, 0.6, p)
			# Knees buckle outward
			if thigh_front:
				thigh_front.rotation = lerpf(0.0, -0.4, p)
			if shin_front:
				shin_front.rotation = lerpf(0.05, 0.85, p)
			if thigh_back:
				thigh_back.rotation = lerpf(0.0, 0.3, p)
			if shin_back:
				shin_back.rotation = lerpf(0.05, 0.80, p)
		
		DeathPhase.COLLAPSE, DeathPhase.PUDDLE_SETTLE, DeathPhase.FINISHED:
			var t_support := death_duration * (pause_ratio + support_loss_ratio)
			var dur_collapse := death_duration * collapse_ratio
			var p := clampf((elapsed - t_support) / maxf(dur_collapse, 0.001), 0.0, 1.0)
			p = ease(p, 0.4) # Fast gravitational collapse
			
			# Pelvis drops down flat to floor level
			var final_pelvis_y := lerpf(-18.0, -3.0, p)
			# Viscous ripple settling at end
			if current_phase == DeathPhase.PUDDLE_SETTLE:
				var ripple := sin((death_progress - 0.77) * 20.0) * exp(-(death_progress - 0.77) * 10.0) * 0.8
				final_pelvis_y += ripple
			pelvis.position = Vector2(0, final_pelvis_y)
			
			if torso:
				torso.position = Vector2(0, lerpf(-12.0, -2.0, p))
				torso.rotation = lerpf(0.35, 0.0, p)
			if head:
				head.position = Vector2(0, lerpf(-8.0, -2.0, p))
				head.rotation = 0.0
			
			# Limbs fold completely into body base
			if upper_front:
				upper_front.rotation = lerpf(0.6, 1.57, p)
			if fore_front:
				fore_front.rotation = lerpf(0.8, 1.57, p)
			if upper_back:
				upper_back.rotation = lerpf(-0.4, -1.57, p)
			if fore_back:
				fore_back.rotation = lerpf(0.6, 1.57, p)
			if thigh_front:
				thigh_front.rotation = lerpf(-0.4, -1.57, p)
			if shin_front:
				shin_front.rotation = lerpf(0.85, 1.57, p)
			if thigh_back:
				thigh_back.rotation = lerpf(0.3, 1.57, p)
			if shin_back:
				shin_back.rotation = lerpf(0.80, 1.57, p)

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

