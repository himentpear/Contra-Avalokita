class_name CombatComponent
extends Node

const HitEvent = preload("res://scripts/hit_event.gd")
const HitData = preload("res://scripts/combat/hit_data.gd")

signal attack_started(id: StringName)
signal hit_confirmed(target: Node)
signal animation_request(clip: StringName, blend: float)
signal damage_requested(amount: float)
signal reaction_started(tier: StringName, direction: Vector2)
signal hit_flash_changed(amount: float, color: Color)

@export var attack_duration := 0.62
@export var allow_air_attack := true
@export_range(0.1, 1.0) var attack_movement_multiplier := 1.0
@export var guard_movement_multiplier := 0.45
@export var punch_animations := PackedStringArray(["Punch/Attack_1", "Punch/Attack_2", "Punch/Attack_3"])
@export var punch_windows: Array[Vector2] = [Vector2(0.06, 0.18), Vector2(0.08, 0.22), Vector2(0.10, 0.26)]
@export var punch_damages: Array[float] = [7.0, 9.0, 12.0]
@export var punch_impacts: Array[float] = [0.50, 0.75, 1.30]
@export var punch_combo_buffer_start := 0.12
@export var enable_camera_shake := false

@export_group("Hit Flash")
@export_range(0.01, 0.30, 0.005) var hit_flash_duration := 0.090
@export_range(0.0, 1.0, 0.05) var hit_flash_peak := 0.95
@export var hit_flash_color := Color.WHITE

var character: CharacterBody2D
var state_component: Node
var punch_hit_targets: Array[int] = []
var punch_hitbox: Area2D
var punch_collision_shape: CollisionShape2D

var _combo_stage := 0
var combo_stage: int:
	get: return state_component.combo_stage if state_component else _combo_stage
	set(v):
		if state_component: state_component.combo_stage = v
		else: _combo_stage = v

var _combo_queued := false
var combo_queued: bool:
	get: return state_component.combo_queued if state_component else _combo_queued
	set(v):
		if state_component: state_component.combo_queued = v
		else: _combo_queued = v

var _action_state: StringName = &"None"
var action_state: StringName:
	get: return state_component.action_state if state_component else _action_state
	set(v):
		if state_component: state_component.action_state = v
		else: _action_state = v

var _attack_time := 0.0
var attack_time: float:
	get: return state_component.attack_time if state_component else _attack_time
	set(v):
		if state_component: state_component.attack_time = v
		else: _attack_time = v

var _attack_requested := false
var attack_requested: bool:
	get: return state_component.attack_requested if state_component else _attack_requested
	set(v):
		if state_component: state_component.attack_requested = v
		else: _attack_requested = v

var block_requested := false

var _reaction_state: StringName = &"None"
var reaction_state: StringName:
	get: return state_component.reaction_state if state_component else _reaction_state
	set(v):
		if state_component: state_component.reaction_state = v
		else: _reaction_state = v

var _reaction_time := 0.0
var reaction_time: float:
	get: return state_component.reaction_time if state_component else _reaction_time
	set(v):
		if state_component: state_component.reaction_time = v
		else: _reaction_time = v

var _reaction_duration := 0.0
var reaction_duration: float:
	get: return state_component.reaction_duration if state_component else _reaction_duration
	set(v):
		if state_component: state_component.reaction_duration = v
		else: _reaction_duration = v

var _reaction_direction := Vector2.RIGHT
var reaction_direction: Vector2:
	get: return state_component.reaction_direction if state_component else _reaction_direction
	set(v):
		if state_component: state_component.reaction_direction = v
		else: _reaction_direction = v

var _reaction_intensity := 1.0
var reaction_intensity: float:
	get: return state_component.reaction_intensity if state_component else _reaction_intensity
	set(v):
		if state_component: state_component.reaction_intensity = v
		else: _reaction_intensity = v

var _reaction_region: StringName = &"UPPER_TORSO"
var reaction_region: StringName:
	get: return state_component.reaction_region if state_component else _reaction_region
	set(v):
		if state_component: state_component.reaction_region = v
		else: _reaction_region = v

var _reaction_impact_local := Vector2.ZERO
var reaction_impact_local: Vector2:
	get: return state_component.reaction_impact_local if state_component else _reaction_impact_local
	set(v):
		if state_component: state_component.reaction_impact_local = v
		else: _reaction_impact_local = v

var _reaction_push_offset := Vector2.ZERO
var reaction_push_offset: Vector2:
	get: return state_component.reaction_push_offset if state_component else _reaction_push_offset
	set(v):
		if state_component: state_component.reaction_push_offset = v
		else: _reaction_push_offset = v

var local_time_scale := 1.0
var hit_flash_remaining := 0.0
var _hit_flash_total := 0.0
var _hit_flash_active_peak := 0.0
var hit_drag_timer := 0.0
var hit_drag_ratio := 0.40

var score_life_id := 0
var score_attack_serial := 0

# Cached skeleton bones
var _upper_arm_front_bone: Bone2D
var _forearm_front_bone: Bone2D
var _hand_front_bone: Bone2D
var _upper_arm_back_bone: Bone2D
var _forearm_back_bone: Bone2D
var _hand_back_bone: Bone2D

func setup(p_character: CharacterBody2D, p_state_component: Node = null) -> void:
	character = p_character
	state_component = p_state_component
	if not punch_hitbox:
		punch_hitbox = Area2D.new()
		punch_hitbox.name = "PunchHitbox"
		punch_hitbox.collision_layer = 0
		punch_hitbox.collision_mask = 4
		punch_hitbox.monitoring = false
		punch_hitbox.monitorable = false
		punch_hitbox.set_meta("owner_character", character)
		punch_collision_shape = CollisionShape2D.new()
		var punch_box := RectangleShape2D.new()
		punch_box.size = Vector2(20, 16)
		punch_collision_shape.shape = punch_box
		punch_hitbox.add_child(punch_collision_shape)
		punch_hitbox.area_entered.connect(_on_punch_area_entered)
		character.add_child(punch_hitbox)
	_cache_bones()

func _cache_bones() -> void:
	if not character: return
	var skeleton: Skeleton2D = character.get_node_or_null("Visual/PoseRoot/Skeleton2D") as Skeleton2D
	if skeleton:
		_upper_arm_front_bone = skeleton.get_node_or_null("Pelvis/Torso/UpperArmFront") as Bone2D
		_forearm_front_bone = skeleton.get_node_or_null("Pelvis/Torso/UpperArmFront/ForearmFront") as Bone2D
		_hand_front_bone = skeleton.get_node_or_null("Pelvis/Torso/UpperArmFront/ForearmFront/HandFront") as Bone2D
		_upper_arm_back_bone = skeleton.get_node_or_null("Pelvis/Torso/UpperArmBack") as Bone2D
		_forearm_back_bone = skeleton.get_node_or_null("Pelvis/Torso/UpperArmBack/ForearmBack") as Bone2D
		_hand_back_bone = skeleton.get_node_or_null("Pelvis/Torso/UpperArmBack/ForearmBack/HandBack") as Bone2D

func is_attacking() -> bool:
	return action_state.begins_with("Attack")

func is_blocking() -> bool:
	if not character: return false
	var is_dead: bool = character.state == &"Dead" if "state" in character else false
	return block_requested and not is_dead and not is_attacking() and reaction_state not in [&"HeavyHit", &"Knockdown"]

func has_reaction() -> bool:
	return reaction_state != &"None" and reaction_time < reaction_duration

func can_attack() -> bool:
	if not character: return false
	var grounded: bool = character.is_on_floor()
	return not is_attacking() and (grounded or allow_air_attack)

func attack() -> void:
	start_attack(0)

func advance_reaction(delta: float) -> void:
	if reaction_time < reaction_duration:
		reaction_time += delta
		if reaction_time >= reaction_duration:
			reaction_state = &"None"
			reaction_push_offset = Vector2.ZERO

func handle_attack_input(grounded: bool) -> void:
	if attack_requested:
		if not is_attacking() and (grounded or allow_air_attack):
			start_attack()
		elif is_attacking():
			var weapons = character.get("weapons") if character else null
			var buffer_start: float = weapons.current.combo_buffer_start if (is_armed() and weapons and weapons.current) else punch_combo_buffer_start
			if attack_time >= attack_duration * buffer_start:
				combo_queued = true
	attack_requested = false

func handle_block_input() -> void:
	if not is_attacking():
		if is_blocking():
			action_state = &"Block"
		elif action_state == &"Block":
			action_state = &"None"

func is_armed() -> bool:
	if not character: return false
	var weapons = character.get("weapons")
	return weapons != null and is_instance_valid(weapons.current)

func attack_animation() -> StringName:
	var weapons = character.get("weapons") if character else null
	if is_armed():
		if weapons.current.weapon_class == "blade" and combo_stage < weapons.current.attack_animations.size():
			return StringName(weapons.current.attack_animations[combo_stage])
		return &"Attack"
	if combo_stage < punch_animations.size():
		var punch_name := StringName(punch_animations[combo_stage])
		var anim_player: AnimationPlayer = character.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim_player and anim_player.has_animation(punch_name):
			return punch_name
	return &"Attack"

func start_attack(stage: int = 0) -> void:
	score_attack_serial += 1
	combo_stage = stage
	combo_queued = false
	attack_time = 0.0
	action_state = StringName("Attack%d" % (stage + 1))
	var anim_name := attack_animation()
	var anim_player: AnimationPlayer = character.get_node_or_null("AnimationPlayer") as AnimationPlayer if character else null
	if anim_player and anim_player.has_animation(anim_name):
		attack_duration = anim_player.get_animation(anim_name).length
	var weapons = character.get("weapons") if character else null
	if is_armed():
		weapons.current.begin_attack(stage)
	else:
		punch_hit_targets.clear()
		if punch_hitbox:
			punch_hitbox.monitoring = false
	attack_started.emit(anim_name)
	animation_request.emit(anim_name, 0.025)

func cancel_attack_pose() -> void:
	action_state = &"None"
	combo_stage = 0
	combo_queued = false
	attack_requested = false
	if punch_hitbox:
		punch_hitbox.set_deferred("monitoring", false)
	var weapons = character.get("weapons") if character else null
	if weapons and weapons.current:
		weapons.current.active = false
		if weapons.current.hitbox:
			weapons.current.hitbox.set_deferred("monitoring", false)

func advance_attack(delta: float) -> void:
	var rate := 1.0
	if hit_drag_timer > 0.0:
		hit_drag_timer = maxf(0.0, hit_drag_timer - delta)
		rate = 1.0 - hit_drag_ratio
	attack_time += delta * rate
	if attack_time < attack_duration: return
	var weapons = character.get("weapons") if character else null
	var max_stages: int = weapons.current.attack_animations.size() if is_armed() and weapons.current.weapon_class == "blade" else punch_animations.size()
	if combo_queued and combo_stage + 1 < max_stages:
		start_attack(combo_stage + 1)
	else:
		combo_stage = 0
		combo_queued = false
		action_state = &"None"
		if punch_hitbox:
			punch_hitbox.monitoring = false

func calculate_punch_reach() -> float:
	var shoulder: Bone2D = _upper_arm_back_bone if combo_stage == 1 and is_instance_valid(_upper_arm_back_bone) else _upper_arm_front_bone
	var fist: Bone2D = _hand_back_bone if combo_stage == 1 and is_instance_valid(_hand_back_bone) else _hand_front_bone
	if not is_instance_valid(shoulder) or not is_instance_valid(fist):
		return 1.0
	var dist: float = (fist.global_position - shoulder.global_position).length()
	return clampf(dist / 28.0, 0.0, 1.0)

func update_punch_attack(_delta: float) -> void:
	if not punch_hitbox or not character: return
	var window := punch_windows[combo_stage] if combo_stage < punch_windows.size() else Vector2(0.08, 0.20)
	var reach := calculate_punch_reach()
	var req_reach: float = 0.55 if combo_stage == 2 else 0.80
	var active := is_attacking() and not is_armed() and attack_time >= window.x and attack_time <= window.y and reach >= req_reach
	punch_hitbox.monitoring = active

	var facing: float = character.get("facing") if "facing" in character else 1.0
	var active_bone: Bone2D = _hand_back_bone if combo_stage == 1 and is_instance_valid(_hand_back_bone) else _hand_front_bone
	if is_instance_valid(active_bone):
		punch_hitbox.global_position = active_bone.global_position + Vector2(facing * 4.0, 0.0)
	else:
		punch_hitbox.global_position = character.global_position + Vector2(facing * 35.0, -32.0)

	if not active: return
	for area in punch_hitbox.get_overlapping_areas():
		_on_punch_area_entered(area)

func _on_punch_area_entered(area: Area2D) -> void:
	if not is_attacking() or is_armed() or not character: return
	var owner_node = area.get_meta("owner_character", null)
	if owner_node == character: return
	var id := area.get_instance_id()
	if punch_hit_targets.has(id): return
	punch_hit_targets.append(id)
	var dmg: float = punch_damages[combo_stage] if combo_stage < punch_damages.size() else 8.0
	var facing: float = character.get("facing") if "facing" in character else 1.0
	var event := HitEvent.new()
	event.attacker = character
	event.attack_name = attack_animation()
	event.attack_token = score_attack_serial
	event.damage = dmg
	event.direction = Vector2(facing, 0.0)
	event.attacker_velocity = character.velocity
	event.weapon_type = &"punch"
	event.impact = punch_impacts[combo_stage] if combo_stage < punch_impacts.size() else 1.0
	event.hit_index = punch_hit_targets.size() - 1
	event.impact_point = punch_hitbox.global_position
	if combo_stage == 0:
		event.hit_type = &"LightHit"
		event.poise_damage = 12.0
		event.impact_force = 55.0
		event.hit_region = &"HEAD"
		event.target_push_distance = 1.8
		event.attacker_drag_ratio = 0.35
		event.camera_shake_strength = 0.0
	elif combo_stage == 1:
		event.hit_type = &"LightHit"
		event.poise_damage = 18.0
		event.impact_force = 90.0
		event.hit_region = &"UPPER_TORSO"
		event.target_push_distance = 2.5
		event.attacker_drag_ratio = 0.40
		event.camera_shake_strength = 0.0
	else:
		event.hit_type = &"HeavyHit"
		event.poise_damage = 35.0
		event.impact_force = 135.0
		event.hit_region = &"HEAD"
		event.target_push_distance = 4.0
		event.attacker_drag_ratio = 0.50
		event.camera_shake_strength = 0.0

	hit_drag_timer = 0.10
	hit_drag_ratio = event.attacker_drag_ratio
	if "impact_accent_offset" in character:
		character.impact_accent_offset = Vector2(-facing * 1.0, 0.0)

	if enable_camera_shake:
		var tree := character.get_tree()
		if tree and tree.current_scene and tree.current_scene.has_method("trigger_camera_shake"):
			tree.current_scene.call("trigger_camera_shake", event.direction, event.camera_shake_strength, 0.08)

	if area.has_method("receive_hit"):
		area.call("receive_hit", event)
	elif area.get_parent() and area.get_parent().has_method("receive_hit"):
		area.get_parent().call("receive_hit", event)

	var splatter = character.get_node_or_null("Visual/PixelMudSplatter")
	if splatter and is_instance_valid(area):
		splatter.burst(area.global_position, 5)

	hit_confirmed.emit(area)

func get_arm_extension_ratio(back_arm := false) -> float:
	var upper: Bone2D = _upper_arm_back_bone if back_arm else _upper_arm_front_bone
	var lower: Bone2D = _forearm_back_bone if back_arm else _forearm_front_bone
	var hand: Bone2D = _hand_back_bone if back_arm else _hand_front_bone
	if not is_instance_valid(upper) or not is_instance_valid(lower) or not is_instance_valid(hand):
		return 0.0
	var parent := upper.get_parent() as Node2D
	if not parent:
		return 0.0
	var reach := lower.position.length() + hand.position.length()
	return parent.to_local(hand.global_position).distance_to(upper.position) / maxf(reach, 0.001)

func set_local_time_scale(scale: float) -> void:
	local_time_scale = maxf(scale, 0.0)
	if character:
		var anim_player: AnimationPlayer = character.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim_player:
			anim_player.speed_scale = local_time_scale

func request_confirmed_hitstop(event: HitEvent) -> void:
	trigger_hit_flash(event)
	if character and character.is_inside_tree():
		var manager := character.get_node_or_null("/root/HitstopManager")
		if manager:
			manager.request_hitstop(event)

func clear_managed_hitstop() -> void:
	if character and character.is_inside_tree():
		var manager := character.get_node_or_null("/root/HitstopManager")
		if manager:
			manager.clear_actor_stop(character)
		else:
			set_local_time_scale(1.0)

func trigger_hit_flash(event: HitData = null) -> void:
	var authored_impact := event.impact if event else 1.0
	var intensity := hit_flash_peak * clampf(0.65 + authored_impact * 0.25, 0.65, 1.0)
	if event and event.is_blocked:
		intensity *= 0.70
	if event and (event.is_critical or event.is_kill or event.is_armor_break or event.is_parry):
		intensity = hit_flash_peak
	var duration_scale := clampf(0.85 + authored_impact * 0.15, 0.85, 1.15)
	var duration := hit_flash_duration * duration_scale
	hit_flash_remaining = maxf(hit_flash_remaining, duration)
	_hit_flash_total = maxf(_hit_flash_total, hit_flash_remaining)
	_hit_flash_active_peak = maxf(_hit_flash_active_peak, intensity)
	hit_flash_changed.emit(_hit_flash_active_peak, hit_flash_color)

func update_hit_flash(delta: float) -> void:
	if hit_flash_remaining <= 0.0:
		return
	hit_flash_remaining = maxf(0.0, hit_flash_remaining - delta)
	var weight := pow(hit_flash_remaining / maxf(_hit_flash_total, 0.001), 0.65)
	hit_flash_changed.emit(_hit_flash_active_peak * weight, hit_flash_color)
	if hit_flash_remaining == 0.0:
		_hit_flash_total = 0.0
		_hit_flash_active_peak = 0.0

func clear_hit_flash() -> void:
	hit_flash_remaining = 0.0
	_hit_flash_total = 0.0
	_hit_flash_active_peak = 0.0
	hit_flash_changed.emit(0.0, hit_flash_color)
