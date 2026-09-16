class_name EquipmentController
extends Node2D

const WeaponData = preload("res://scripts/resources/weapon_data.gd")
const MudWeapon = preload("res://gameplay/combat/weapons/weapon.gd")

signal weapon_equipped(weapon: MudWeapon, data: WeaponData)
signal weapon_unequipped()
signal weapon_dropped_to_ground()
signal carry_mode_changed(previous: int, current_mode: int)

enum CarryMode { HAND, BACK }

@export var default_weapon: PackedScene = preload("res://scenes/weapons/sword.tscn")
@export var default_weapon_data: WeaponData = null

var main_hand: Marker2D
var back_slot: Marker2D
var current: MudWeapon
var current_data: WeaponData
var owner_character: Node
var hand_depth := 1.0
@export var blade_projection := 1.0
@export var blade_depth := 0.0
@export_group("Weapon Carry")
@export_enum("HAND", "BACK") var default_carry_mode: int = CarryMode.BACK
# The grip sits just outside the rear torso silhouette. Rotation owns the nearly
# vertical direction; skew supplies the shallow back-plane perspective.
@export var back_slot_offset := Vector2(-9.0, -20.0)
@export_range(0.0, 32.0, 1.0) var back_slot_vertical_drop := 16.0
@export_range(-180.0, 180.0, 0.5) var back_slot_rotation_degrees := 92.0
@export_range(-30.0, 30.0, 0.5) var back_slot_skew_degrees := 12.0
@export_range(-10, 10, 1) var back_slot_z_index := -5
@export_group("")
var carry_mode := CarryMode.BACK
var action_requires_hand := false

var weapon_dropped := false
var weapon_grounded := false
var drop_pos := Vector2.ZERO
var drop_vel := Vector2.ZERO
var drop_rot := 0.0
var drop_angular_vel := 0.0

var current_weapon_rot := 0.0
var weapon_spring_vel := 0.0

var equipment_manager: Node = null

func _ready() -> void:
	main_hand = get_node_or_null("MainHandSlot") as Marker2D
	if not main_hand:
		main_hand = Marker2D.new()
		main_hand.name = "MainHandSlot"
		main_hand.set_meta("anatomical_hand", &"Right")
		add_child(main_hand)
	back_slot = get_node_or_null("BackSlot") as Marker2D
	if not back_slot:
		back_slot = Marker2D.new()
		back_slot.name = "BackSlot"
		add_child(back_slot)
	back_slot.z_index = back_slot_z_index
	carry_mode = default_carry_mode
	if default_weapon_data:
		equip(default_weapon_data)
	elif default_weapon:
		equip(default_weapon)

func setup_equipment(p_equipment: Node) -> void:
	equipment_manager = p_equipment

func equip(source: Variant) -> void:
	if is_instance_valid(current):
		_disable_weapon_combat()
		current.queue_free()
	current = null
	current_data = null

	if source == null:
		weapon_unequipped.emit()
		return

	if source is WeaponData:
		current_data = source
		if source.weapon_scene:
			current = source.weapon_scene.instantiate() as MudWeapon
			assert(current != null, "Weapons must extend MudWeapon")
			_apply_weapon_data(current, source)
	elif source is PackedScene:
		current = source.instantiate() as MudWeapon
		assert(current != null, "Weapons must extend MudWeapon")
	elif source is MudWeapon:
		current = source

	if is_instance_valid(current):
		current.set_meta("owner_character", owner_character)
		var target_slot := _slot_for_mode(carry_mode)
		if is_instance_valid(target_slot):
			target_slot.add_child(current)
			if current.has_node("WeaponGrip"):
				current.position = -current.get_node("WeaponGrip").position
			current.rotation = 0.0
		current.set_combat_enabled(carry_mode == CarryMode.HAND)
		weapon_equipped.emit(current, current_data)

func is_weapon_in_hand() -> bool:
	return carry_mode == CarryMode.HAND and is_instance_valid(current) and current.get_parent() == main_hand

func set_carry_mode(mode: int, _animated := false) -> void:
	# _animated is reserved for a future draw/sheathe transition. MVP switches immediately.
	var next_mode := clampi(mode, CarryMode.HAND, CarryMode.BACK)
	var previous := carry_mode
	carry_mode = next_mode
	if next_mode == CarryMode.BACK:
		_disable_weapon_combat()
	if is_instance_valid(current):
		var target_slot := _slot_for_mode(next_mode)
		if is_instance_valid(target_slot) and current.get_parent() != target_slot:
			current.reparent(target_slot, false)
			current.position = -current.get_node("WeaponGrip").position if current.has_node("WeaponGrip") else Vector2.ZERO
			current.rotation = 0.0
		current.scale = Vector2.ONE
		current.modulate = Color.WHITE
		current.set_combat_enabled(next_mode == CarryMode.HAND)
	if previous != carry_mode:
		carry_mode_changed.emit(previous, carry_mode)

func update_carry_mode(attacking: bool, blocking: bool, requires_hand := false) -> void:
	set_carry_mode(CarryMode.HAND if attacking or blocking or requires_hand or action_requires_hand else CarryMode.BACK)

func set_action_requires_hand(required: bool, animated := false) -> void:
	# Extension seam for future draw/sheathe actions outside attack and guard.
	action_requires_hand = required
	var attacking := is_instance_valid(owner_character) and owner_character.has_method("is_attacking") and bool(owner_character.is_attacking())
	var blocking := is_instance_valid(owner_character) and owner_character.has_method("is_blocking") and bool(owner_character.is_blocking())
	set_carry_mode(CarryMode.HAND if attacking or blocking or required else CarryMode.BACK, animated)

func _slot_for_mode(mode: int) -> Marker2D:
	return main_hand if mode == CarryMode.HAND else back_slot

func _disable_weapon_combat() -> void:
	if not is_instance_valid(current):
		return
	current.set_combat_enabled(false)

func _apply_weapon_data(weapon: MudWeapon, data: WeaponData) -> void:
	if not weapon or not data: return
	weapon.weapon_name = data.display_name
	weapon.weapon_class = data.weapon_class
	weapon.attack_animations = data.attack_animations
	weapon.attack_windows = data.attack_windows
	weapon.combo_buffer_start = data.combo_buffer_start
	weapon.feedback_weapon_type = data.feedback_weapon_type
	if not data.attack_damages.is_empty():
		weapon.damage = data.attack_damages[0]
	if not data.combo_impacts.is_empty():
		weapon.combo_impacts = data.combo_impacts
	blade_projection = data.blade_projection
	blade_depth = data.blade_depth

func is_armed() -> bool:
	return is_instance_valid(current)

func drop_weapon_to_ground() -> void:
	if not is_instance_valid(current) or weapon_dropped: return
	weapon_dropped = true
	weapon_grounded = false
	if is_instance_valid(current):
		var local_transform := global_transform.affine_inverse() * current.global_transform
		drop_pos = local_transform.origin
		drop_rot = local_transform.get_rotation()
		current.reparent(self, false)
		current.position = drop_pos
		current.rotation = drop_rot
		current.z_index = 6
	else:
		drop_pos = Vector2(10, -20)
		drop_rot = 0.0
	drop_vel = Vector2(18.0, -30.0)
	drop_angular_vel = 3.5
	if current.has_node("Hitbox"):
		(current.get_node("Hitbox") as Area2D).set_deferred("monitoring", false)
	current.active = false
	weapon_dropped_to_ground.emit()

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
		if is_instance_valid(current):
			current.position = drop_pos
			current.rotation = drop_rot

func sync_bone(hand_bone: Bone2D, forearm_bone: Bone2D, attack_time: float, attacking: bool, delta: float = 0.0167, back_bone: Bone2D = null, spine_bone: Bone2D = null) -> void:
	if not is_instance_valid(main_hand): return
	if weapon_dropped: return
	_sync_back_slot(back_bone, spine_bone)
	var blocking: bool = not attacking and is_instance_valid(owner_character) and owner_character.has_method("is_blocking") and bool(owner_character.is_blocking())
	update_carry_mode(attacking, blocking)
	if is_instance_valid(hand_bone):
		main_hand.position = to_local(hand_bone.global_position)
		var is_blocking_armed: bool = blocking
		if is_blocking_armed:
			# Sword Guard: tilted 7° forward toward enemy (-PI/2 + 7°), hilt near body
			var base_guard_rot: float = -PI * 0.5 + deg_to_rad(7.0)
			var recoil_rot := 0.0
			if owner_character.has_method("has_reaction") and owner_character.has_reaction() and owner_character.reaction_state == &"BlockHit":
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
			var raw_angle := 0.0
			if is_instance_valid(forearm_bone):
				var dir := to_local(hand_bone.global_position) - to_local(forearm_bone.global_position)
				if dir.length_squared() > 0.001:
					raw_angle = dir.angle()
			var base_angle := 0.12
			var deflection := clampf(raw_angle * 0.08, -deg_to_rad(3.0), deg_to_rad(3.0))
			var target_rot := base_angle + deflection
			var rot_diff := angle_difference(current_weapon_rot, target_rot)
			weapon_spring_vel += rot_diff * 45.0 * delta
			weapon_spring_vel *= exp(-22.0 * delta)
			current_weapon_rot += weapon_spring_vel * delta
			main_hand.rotation = current_weapon_rot
	if carry_mode == CarryMode.BACK:
		return
	var is_blocking_armed: bool = blocking
	if current:
		var horizontal := attacking and current.weapon_class == "blade" and current.attack_stage == 1
		current.scale = Vector2((maxf(absf(blade_projection), .08) * (-1.0 if blade_projection < 0 else 1.0)) if horizontal else 1.0, 1.0)
		current.modulate = Color(.8, .8, .8, 1) if horizontal and blade_depth < -.5 else Color.WHITE
	if is_blocking_armed:
		main_hand.z_index = 8
	else:
		main_hand.z_index = -4 if hand_depth < -.5 else (6 if hand_depth > .5 else 2)
	if current and carry_mode == CarryMode.HAND: current.update_attack(attack_time, attacking)

func _sync_back_slot(back_bone: Bone2D, spine_bone: Bone2D = null) -> void:
	if not is_instance_valid(back_slot):
		return
	back_slot.z_index = back_slot_z_index
	back_slot.skew = deg_to_rad(back_slot_skew_degrees)
	if not is_instance_valid(back_bone):
		back_slot.position = Vector2(-9.0, -59.0)
		back_slot.rotation = deg_to_rad(back_slot_rotation_degrees)
		return
	var origin := to_local(back_bone.global_position)
	var axis := to_local(back_bone.to_global(Vector2.RIGHT)) - origin
	var bone_angle := axis.angle() if axis.length_squared() > 0.001 else 0.0
	var dropped_offset := back_slot_offset + Vector2.DOWN * back_slot_vertical_drop
	back_slot.position = origin + dropped_offset.rotated(bone_angle)
	var slope_bone := spine_bone if is_instance_valid(spine_bone) else back_bone
	var slope_origin := to_local(slope_bone.global_position)
	var slope_axis := to_local(slope_bone.to_global(Vector2.RIGHT)) - slope_origin
	var spine_angle := slope_axis.angle() if slope_axis.length_squared() > 0.001 else 0.0
	back_slot.rotation = spine_angle + deg_to_rad(back_slot_rotation_degrees)

func sync(rig: MudRig, attack_time: float, attacking: bool, delta: float = 0.0167) -> void:
	if not is_instance_valid(main_hand) or rig == null: return
	if weapon_dropped: return
	_sync_back_slot(null, null)
	var blocking: bool = not attacking and is_instance_valid(owner_character) and owner_character.has_method("is_blocking") and bool(owner_character.is_blocking())
	update_carry_mode(attacking, blocking)
	main_hand.position = rig.point(&"ArmFrontEnd")
	if carry_mode == CarryMode.BACK:
		return
	var is_blocking_armed: bool = blocking
	if is_blocking_armed:
		var base_guard_rot: float = -PI * 0.5 + deg_to_rad(7.0)
		var recoil_rot := 0.0
		if owner_character.has_method("has_reaction") and owner_character.has_reaction() and owner_character.reaction_state == &"BlockHit":
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
	if current and carry_mode == CarryMode.HAND: current.update_attack(attack_time, attacking)

func equip_piece(slot: StringName, scene: PackedScene) -> void:
	if equipment_manager and equipment_manager.has_method("equip"):
		equipment_manager.equip(slot, scene)

func toggle_equipment() -> void:
	if equipment_manager and equipment_manager.has_method("toggle"):
		equipment_manager.toggle()

func sync_equipment_bones(head_bone: Bone2D, forearm_bone: Bone2D, hand_bone: Bone2D) -> void:
	if equipment_manager and equipment_manager.has_method("sync_bones"):
		equipment_manager.sync_bones(head_bone, forearm_bone, hand_bone)

func sync_equipment_handedness(left_forearm: Bone2D, left_hand: Bone2D, right_depth: float, left_depth: float) -> void:
	if equipment_manager and equipment_manager.has_method("sync_handedness"):
		equipment_manager.sync_handedness(left_forearm, left_hand, right_depth, left_depth)

func sync_equipment_death(death_progress: float, embed: bool) -> void:
	if equipment_manager and equipment_manager.has_method("sync_death"):
		equipment_manager.sync_death(death_progress, embed)
