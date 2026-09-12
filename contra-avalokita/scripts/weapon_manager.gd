class_name WeaponManager
extends Node2D
@export var default_weapon: PackedScene = preload("res://scenes/weapons/sword.tscn")
var main_hand: Marker2D
var current: MudWeapon
var owner_character: Node
var hand_depth := 1.0
@export var blade_projection := 1.0
@export var blade_depth := 0.0

func _ready() -> void:
	main_hand = Marker2D.new()
	main_hand.name = "MainHandSlot"
	main_hand.set_meta("anatomical_hand",&"Right")
	add_child(main_hand)
	equip(default_weapon)

func equip(scene: PackedScene) -> void:
	if is_instance_valid(current):
		main_hand.remove_child(current)
		current.queue_free()
	current = null
	if scene:
		current = scene.instantiate() as MudWeapon
		assert(current != null, "Weapons must extend MudWeapon")
		current.set_meta("owner_character", owner_character)
		main_hand.add_child(current)
		current.position = -current.get_node("WeaponGrip").position

var weapon_dropped := false
var weapon_grounded := false
var drop_pos := Vector2.ZERO
var drop_vel := Vector2.ZERO
var drop_rot := 0.0
var drop_angular_vel := 0.0

func drop_weapon_to_ground() -> void:
	if not is_instance_valid(current) or weapon_dropped: return
	weapon_dropped = true
	weapon_grounded = false
	if is_instance_valid(main_hand):
		drop_pos = main_hand.position
		drop_rot = main_hand.rotation
	else:
		drop_pos = Vector2(10, -20)
		drop_rot = 0.0
	drop_vel = Vector2(18.0, -30.0)
	drop_angular_vel = 3.5
	if current.has_node("Hitbox"):
		(current.get_node("Hitbox") as Area2D).set_deferred("monitoring", false)
	current.active = false

func _process(delta: float) -> void:
	if weapon_dropped and not weapon_grounded:
		drop_vel.y += 500.0 * delta
		drop_pos += drop_vel * delta
		drop_rot += drop_angular_vel * delta
		if drop_pos.y >= -2.0:
			drop_pos.y = -2.0
			drop_vel = Vector2.ZERO
			drop_rot = lerpf(drop_rot, 0.0, 0.5)
			weapon_grounded = true
		if is_instance_valid(main_hand):
			main_hand.position = drop_pos
			main_hand.rotation = drop_rot

var current_weapon_rot := 0.0
var weapon_spring_vel := 0.0

func sync_bone(hand_bone: Bone2D, forearm_bone: Bone2D, attack_time: float, attacking: bool, delta: float = 0.0167) -> void:
	if not is_instance_valid(main_hand): return
	if weapon_dropped: return
	if is_instance_valid(hand_bone):
		main_hand.position = to_local(hand_bone.global_position)
		var is_blocking_armed: bool = not attacking and is_instance_valid(owner_character) and owner_character.has_method("is_blocking") and owner_character.is_blocking()
		if is_blocking_armed:
			# Sword Guard: tilted 7° forward toward enemy (-PI/2 + 7°), hilt near body
			var base_guard_rot: float = -PI * 0.5 + deg_to_rad(7.0)
			var recoil_rot := 0.0
			if owner_character.has_reaction() and owner_character.reaction_state == &"BlockHit":
				var dur: float = maxf(owner_character.reaction_duration, 0.001)
				var p: float = clampf(owner_character.reaction_time / dur, 0.0, 1.0)
				var push_x: float = owner_character.reaction_direction.x * owner_character.facing
				var w_arm: float = sin(clampf(p / 0.50, 0.0, 1.0) * PI) * exp(-p * 1.5)
				recoil_rot = push_x * deg_to_rad(6.5) * w_arm
				if owner_character.reaction_direction.y > 0.3:
					main_hand.position.y += 2.0 * owner_character.reaction_direction.y * w_arm
			current_weapon_rot = base_guard_rot + recoil_rot
			weapon_spring_vel = 0.0
			main_hand.rotation = current_weapon_rot
			main_hand.z_index = 8
		elif (attacking and current and current.weapon_class == "blade") or (not attacking and is_instance_valid(owner_character) and owner_character.get("state") in [&"Walk", &"Run"]):
			# These animations author blade orientation on HandFront, including wrist lag.
			# Convert its axis through this visual space so facing-left remains correct.
			var hand_axis := to_local(hand_bone.to_global(Vector2.RIGHT)) - to_local(hand_bone.global_position)
			current_weapon_rot = hand_axis.angle()
			weapon_spring_vel = 0.0
			main_hand.rotation = current_weapon_rot
		elif attacking:
			if is_instance_valid(forearm_bone):
				var dir := to_local(hand_bone.global_position) - to_local(forearm_bone.global_position)
				if dir.length_squared() > 0.001:
					current_weapon_rot = dir.angle()
				else:
					current_weapon_rot = 0.0
			else:
				current_weapon_rot = 0.0
			weapon_spring_vel = 0.0
			main_hand.rotation = current_weapon_rot
		else:
			# Locomotion / Idle: stabilize blade angle, subtle 2-3 frame rotational inertia, only 2-4 degrees of motion
			var raw_angle := 0.0
			if is_instance_valid(forearm_bone):
				var dir := to_local(hand_bone.global_position) - to_local(forearm_bone.global_position)
				if dir.length_squared() > 0.001:
					raw_angle = dir.angle()
			var base_angle := 0.12 # natural forward-tilted blade angle (~7 degrees)
			# Subtle 2-4 degrees (0.035 - 0.07 rad) rotational inertia from arm swing
			var deflection := clampf(raw_angle * 0.08, -deg_to_rad(3.0), deg_to_rad(3.0))
			var target_rot := base_angle + deflection
			var rot_diff := angle_difference(current_weapon_rot, target_rot)
			weapon_spring_vel += rot_diff * 45.0 * delta
			weapon_spring_vel *= exp(-22.0 * delta)
			current_weapon_rot += weapon_spring_vel * delta
			main_hand.rotation = current_weapon_rot
	var is_blocking_armed: bool = not attacking and is_instance_valid(owner_character) and owner_character.has_method("is_blocking") and owner_character.is_blocking()
	if current:
		var horizontal := attacking and current.weapon_class == "blade" and current.attack_stage == 1
		current.scale = Vector2((maxf(absf(blade_projection),.08) * (-1.0 if blade_projection < 0 else 1.0)) if horizontal else 1.0, 1.0)
		current.modulate = Color(.8,.8,.8,1) if horizontal and blade_depth < -.5 else Color.WHITE
	# Final layer comes from the same anatomical/attack depth used by the right arm.
	if is_blocking_armed:
		main_hand.z_index = 8
	else:
		main_hand.z_index = -4 if hand_depth < -.5 else (6 if hand_depth > .5 else 2)
	if current: current.update_attack(attack_time, attacking)

func sync(rig: MudRig, attack_time: float, attacking: bool, delta: float = 0.0167) -> void:
	if not is_instance_valid(main_hand) or rig == null: return
	if weapon_dropped: return
	main_hand.position = rig.point(&"ArmFrontEnd")
	var is_blocking_armed: bool = not attacking and is_instance_valid(owner_character) and owner_character.has_method("is_blocking") and owner_character.is_blocking()
	if is_blocking_armed:
		var base_guard_rot: float = -PI * 0.5 + deg_to_rad(7.0)
		var recoil_rot := 0.0
		if owner_character.has_reaction() and owner_character.reaction_state == &"BlockHit":
			var dur: float = maxf(owner_character.reaction_duration, 0.001)
			var p: float = clampf(owner_character.reaction_time / dur, 0.0, 1.0)
			var push_x: float = owner_character.reaction_direction.x * owner_character.facing
			var w_arm: float = sin(clampf(p / 0.50, 0.0, 1.0) * PI) * exp(-p * 1.5)
			recoil_rot = push_x * deg_to_rad(6.5) * w_arm
			if owner_character.reaction_direction.y > 0.3:
				main_hand.position.y += 2.0 * owner_character.reaction_direction.y * w_arm
		current_weapon_rot = base_guard_rot + recoil_rot
		weapon_spring_vel = 0.0
		main_hand.rotation = current_weapon_rot
		main_hand.z_index = 8
	elif attacking:
		current_weapon_rot = rig.weapon_angle
		weapon_spring_vel = 0.0
		main_hand.rotation = current_weapon_rot
		main_hand.z_index = 6 if attack_time > 0.18 else -2
	else:
		var base_angle := 0.12
		var deflection := clampf(rig.weapon_angle * 0.08, -deg_to_rad(3.0), deg_to_rad(3.0))
		var target_rot := base_angle + deflection
		var rot_diff := angle_difference(current_weapon_rot, target_rot)
		weapon_spring_vel += rot_diff * 45.0 * delta
		weapon_spring_vel *= exp(-22.0 * delta)
		current_weapon_rot += weapon_spring_vel * delta
		main_hand.rotation = current_weapon_rot
		main_hand.z_index = 6
	if current: current.update_attack(attack_time, attacking)
