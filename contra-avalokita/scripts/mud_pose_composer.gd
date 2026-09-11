class_name MudPoseComposer
extends Node2D
## Base animation is evaluated first. Only explicitly owned bones receive action poses.
@export var idle_pelvis_limit := 0.14
@export var moving_pelvis_limit := 0.06
@export var air_pelvis_limit := 0.035
@export var attack_blend_in := 0.055
@export_range(0.4,0.95) var recovery_start := 0.68
var character: MudCharacter
var base_pose: Dictionary = {}
var weight := 0.0

func restore_base() -> void:
	for bone in base_pose:
		if is_instance_valid(bone): bone.transform = base_pose[bone]

func evaluate(delta: float) -> void:
	var player := character.anim_player
	if character.state in [&"Jump", &"Fall"] and not String(player.current_animation).begins_with("Air/"):
		var vertical := character.velocity.y
		var progress := 1.0-clampf(-vertical/absf(character.jump_velocity),0,1) if vertical < 0 else clampf(vertical/absf(character.jump_velocity),0,1)
		player.seek(progress*player.current_animation_length,true)
		player.advance(0.0)
	else:
		player.advance(delta)
	base_pose.clear()
	for bone in character.skeleton.find_children("*","Bone2D"):
		base_pose[bone] = bone.transform
	weight = 0.0
	character.weapons.blade_projection = 1.0
	character.weapons.blade_depth = 0.0
	if character.is_attacking():
		apply_action()
	if character.has_reaction():
		apply_reaction(delta)
	queue_redraw()

func apply_action() -> void:
	var clip := character.anim_player.get_animation(character.attack_animation())
	var t := character.attack_time
	weight = smoothstep(0.0,attack_blend_in,t) * (1.0-smoothstep(clip.length*recovery_start,clip.length,t))
	var pelvis := character.skeleton.get_node("Pelvis") as Bone2D
	var is_unarmed_stationary: bool = not character.is_armed() and character.state == &"Idle" and character.is_on_floor()
	var legs: Dictionary = {}
	if not is_unarmed_stationary:
		for side in ["Front","Back"]:
			var leg := pelvis.get_node("Thigh"+side) as Bone2D
			legs[leg] = leg.global_transform
	for track in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_VALUE or not clip.track_is_enabled(track): continue
		var target := String(clip.track_get_path(track)).split(":")
		if target.size() != 2: continue
		var node := character.get_node_or_null(NodePath(target[0]))
		var property := target[1]
		var value = clip.value_track_interpolate(track,t)
		if node == pelvis:
			if property == "rotation":
				if is_unarmed_stationary:
					pelvis.rotation = lerp_angle(pelvis.rotation, float(value), weight)
				else:
					var limit := idle_pelvis_limit if character.state == &"Idle" else (air_pelvis_limit if character.state in [&"Jump",&"Fall"] else (0.18 if not character.is_armed() else moving_pelvis_limit))
					pelvis.rotation += clampf(float(value)-.04,-limit,limit)*weight
			elif property == "position" and is_unarmed_stationary:
				pelvis.position = pelvis.position.lerp(value, weight)
		elif node is Bone2D and "/Torso" in target[0]:
			if property == "rotation": node.rotation = lerp_angle(node.rotation,float(value),weight)
			elif property == "position": node.position = node.position.lerp(value,weight)
		elif node is Bone2D and is_unarmed_stationary and ("/Thigh" in target[0] or "/Shin" in target[0] or "/Foot" in target[0]):
			if property == "rotation": node.rotation = lerp_angle(node.rotation,float(value),weight)
		elif node == character.weapons and property in ["blade_projection","blade_depth"]:
			node.set(property,lerpf(float(node.get(property)),float(value),weight))
	# Compensate for pelvis vertical bob on torso during punches to stabilize active punch height
	var torso := character.skeleton.get_node_or_null("Pelvis/Torso") as Bone2D
	if torso:
		if not character.is_armed() and character.state in [&"Walk", &"Run"]:
			var locomotion_bob_y: float = pelvis.position.y - (-33.0)
			torso.position.y += -locomotion_bob_y * 0.4 * weight
		if "impact_accent_offset" in character:
			torso.position += character.impact_accent_offset * weight
		if character.hit_stop_duration > 0.0 or character.hit_drag_timer > 0.0:
			var wrist: Bone2D = character._hand_front_bone if is_instance_valid(character._hand_front_bone) else null
			if wrist:
				wrist.position.x += -1.2 * weight
			torso.rotation += -0.06 * weight
	# The shared pelvis twist must not rotate hip offsets, knees or planted feet during locomotion or blade attacks.
	if not is_unarmed_stationary:
		var active_damping: float = 0.12 * weight if (not character.is_armed() and character.state in [&"Walk", &"Run"]) else 0.0
		for leg in legs:
			leg.global_transform = legs[leg]
			if active_damping > 0.0:
				leg.rotation = lerpf(leg.rotation, 0.0, active_damping)

func apply_reaction(_delta: float) -> void:
	if not character or not character.has_reaction(): return
	var t: float = character.reaction_time
	var dur: float = maxf(character.reaction_duration, 0.001)
	var p: float = clampf(t / dur, 0.0, 1.0)
	
	# Two-phase recoil curves:
	# 1. Linear Push (Immediate on contact, 0.0 to 0.18): whole body displaced along attack direction
	# 2. Rotational Strain (Lags behind, peaks 0.25 to 0.40): torso & head arch backward
	var push_weight: float = 0.0
	var rot_weight: float = 0.0
	
	if p < 0.18:
		push_weight = sin(p / 0.18 * PI * 0.5)
		rot_weight = smoothstep(0.06, 0.18, p) * 0.35
	else:
		var decay_p := (p - 0.18) / 0.82
		push_weight = cos(decay_p * PI * 0.5) * exp(-decay_p * 1.5)
		if p < 0.38:
			rot_weight = 0.35 + 0.65 * sin((p - 0.18) / 0.20 * PI * 0.5)
		else:
			var decay_rot := (p - 0.38) / 0.62
			rot_weight = cos(decay_rot * PI * 0.5) * exp(-decay_rot * 2.2)

	push_weight = clampf(push_weight, 0.0, 1.3) * character.reaction_intensity
	rot_weight = clampf(rot_weight, 0.0, 1.3) * character.reaction_intensity
	
	# Direction mapping in local space (facing: 1 or -1)
	var local_x: float = character.reaction_direction.x * character.facing
	var local_y: float = character.reaction_direction.y
	var local_dir := Vector2(local_x, local_y)
	
	var pelvis := character.skeleton.get_node_or_null("Pelvis") as Bone2D
	var torso := character.skeleton.get_node_or_null("Pelvis/Torso") as Bone2D
	var head := character.skeleton.get_node_or_null("Pelvis/Torso/Head") as Bone2D
	if not pelvis or not torso or not head: return
	
	var tier: StringName = character.reaction_state
	var region: StringName = character.reaction_region
	
	var tier_scale := 1.0
	match tier:
		&"MicroHit": tier_scale = 0.35
		&"LightHit": tier_scale = 1.0
		&"AirHit": tier_scale = 1.15
		&"HeavyHit": tier_scale = 1.85
		&"Knockdown": tier_scale = 2.4
		
	var w_push := push_weight * tier_scale
	var w_rot := rot_weight * tier_scale
	
	match region:
		&"HEAD":
			head.rotation += local_dir.x * 0.28 * w_rot
			head.position += Vector2(local_dir.x * 3.5, local_dir.y * 1.5) * w_push
			torso.rotation += local_dir.x * 0.12 * w_rot
			torso.position += Vector2(local_dir.x * 1.8, local_dir.y * 0.8) * w_push
			pelvis.position.x += local_dir.x * 0.8 * w_push
		&"LOWER_TORSO", &"LEG":
			pelvis.position += Vector2(local_dir.x * 2.8, local_dir.y * 1.4) * w_push
			pelvis.rotation += local_dir.x * 0.08 * w_rot
			torso.position += Vector2(local_dir.x * 1.8, local_dir.y * 0.8) * w_push
			head.position += Vector2(local_dir.x * 1.0, 0.0) * w_push
		_: # UPPER_TORSO
			torso.rotation += local_dir.x * 0.24 * w_rot
			torso.position += Vector2(local_dir.x * 4.2, local_dir.y * 1.8) * w_push
			head.position += Vector2(local_dir.x * 2.4, local_dir.y * 1.0) * w_push
			head.rotation += -local_dir.x * 0.08 * w_rot
			pelvis.position.x += local_dir.x * 1.6 * w_push
			
	if tier in [&"HeavyHit", &"Knockdown"]:
		torso.rotation += local_dir.x * 0.18 * w_rot
		pelvis.position.y += 2.0 * w_rot

func _draw() -> void:
	if not is_instance_valid(character) or not character.rig or not character.rig.debug_draw: return
	for bone in base_pose:
		var color := Color("48dca4")
		if bone.name == "Pelvis": color = Color("ffd467")
		elif "/Torso" in String(bone.get_path()): color = Color("ff8697") if weight > 0 else Color("48dca4")
		var origin := to_local(bone.global_position)
		draw_circle(origin,1.6,color)
		for child in bone.get_children():
			if child is Bone2D: draw_line(origin,to_local(child.global_position),color,1.0)
