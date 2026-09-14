class_name MudCharacter
extends CharacterBody2D
@export var blade_footwork: Resource = preload("res://resources/blade_footwork.tres")
const HitEvent = preload("res://scripts/hit_event.gd")
const IntentComponentScript = preload("res://gameplay/components/movement/intent_component.gd")
const MovementComponent = preload("res://scripts/components/movement_component.gd")
signal state_changed(previous: StringName, current: StringName)
signal damaged(amount: float)
signal footstep(side: StringName)
signal landed(impact_speed: float, hard: bool)
signal wall_action_changed(previous: StringName, current: StringName)
signal wall_jumped(direction: Vector2)
signal unfallen_started(duration: float)
signal unfallen_ended
signal jump_executed(source: MudMovementAssist.JumpSource)
@export var jump_squat_duration := 0.075
@export var takeoff_duration := 0.075
@export var minimum_landing_air_time := 0.08
@export var soft_landing_speed := 140.0
@export var hard_landing_speed := 280.0
@export var apex_threshold := 35.0
@export var landing_recovery_duration := 0.07
@export var movement_assist_debug := false
var movement_component: MovementComponent

var air_time: float:
	get: return movement_component.air_time if movement_component else 0.0
	set(v): if movement_component: movement_component.air_time = v
var last_air_velocity_y: float:
	get: return movement_component.last_air_velocity_y if movement_component else 0.0
	set(v): if movement_component: movement_component.last_air_velocity_y = v
var jump_phase: StringName:
	get: return movement_component.jump_phase if movement_component else &"Grounded"
	set(v): if movement_component: movement_component.jump_phase = v
var jump_squat_left: float:
	get: return movement_component.jump_squat_left if movement_component else 0.0
	set(v): if movement_component: movement_component.jump_squat_left = v
var landing_left: float:
	get: return movement_component.landing_left if movement_component else 0.0
	set(v): if movement_component: movement_component.landing_left = v
var landing_animation: StringName:
	get: return movement_component.landing_animation if movement_component else &""
	set(v): if movement_component: movement_component.landing_animation = v
var grounded_resume_phase: float:
	get: return movement_component.grounded_resume_phase if movement_component else 0.0
	set(v): if movement_component: movement_component.grounded_resume_phase = v
var movement_assist: MudMovementAssist:
	get: return movement_component.movement_assist if movement_component else null
var item_inventory: MudItemInventory:
	get: return movement_component.item_inventory if movement_component else null
var pending_jump_source: MudMovementAssist.JumpSource:
	get: return movement_component.pending_jump_source if movement_component else MudMovementAssist.JumpSource.NONE
	set(v): if movement_component: movement_component.pending_jump_source = v

var wall_action: StringName:
	get: return movement_component.wall_action if movement_component else &"None"
	set(v): if movement_component: movement_component.wall_action = v
var wall_side: float:
	get: return movement_component.wall_side if movement_component else 0.0
	set(v): if movement_component: movement_component.wall_side = v
var wall_action_time: float:
	get: return movement_component.wall_action_time if movement_component else 0.0
	set(v): if movement_component: movement_component.wall_action_time = v
var wall_hang_left: float:
	get: return movement_component.wall_hang_left if movement_component else 0.0
	set(v): if movement_component: movement_component.wall_hang_left = v
var wall_surface_x: float:
	get: return movement_component.wall_surface_x if movement_component else INF
	set(v): if movement_component: movement_component.wall_surface_x = v
var wall_hand_anchor_y: float:
	get: return movement_component.wall_hand_anchor_y if movement_component else 0.0
	set(v): if movement_component: movement_component.wall_hand_anchor_y = v
var wall_foot_anchor_y: float:
	get: return movement_component.wall_foot_anchor_y if movement_component else 0.0
	set(v): if movement_component: movement_component.wall_foot_anchor_y = v
var wall_slide_scrape_offset: float:
	get: return movement_component.wall_slide_scrape_offset if movement_component else 0.0
	set(v): if movement_component: movement_component.wall_slide_scrape_offset = v
var wall_front_knee_sign: float:
	get: return movement_component.wall_front_knee_sign if movement_component else 0.0
	set(v): if movement_component: movement_component.wall_front_knee_sign = v
var wall_back_knee_sign: float:
	get: return movement_component.wall_back_knee_sign if movement_component else 0.0
	set(v): if movement_component: movement_component.wall_back_knee_sign = v
var wall_slide_speed: float:
	get: return movement_component.wall_slide_speed if movement_component else 58.0
	set(v): if movement_component: movement_component.wall_slide_speed = v
var wall_climb_jump_velocity: float:
	get: return movement_component.wall_climb_jump_velocity if movement_component else 245.0
	set(v): if movement_component: movement_component.wall_climb_jump_velocity = v
var wall_climb_detach_velocity: float:
	get: return movement_component.wall_climb_detach_velocity if movement_component else 55.0
	set(v): if movement_component: movement_component.wall_climb_detach_velocity = v
var wall_regrab_left: float:
	get: return movement_component.wall_regrab_left if movement_component else 0.0
	set(v): if movement_component: movement_component.wall_regrab_left = v
var pending_wall_jump_kind: StringName:
	get: return movement_component.pending_wall_jump_kind if movement_component else &"Standard"
	set(v): if movement_component: movement_component.pending_wall_jump_kind = v
var wall_push_duration: float:
	get: return movement_component.wall_push_duration if movement_component else 0.075
	set(v): if movement_component: movement_component.wall_push_duration = v
var wall_release_duration: float:
	get: return movement_component.wall_release_duration if movement_component else 0.14
	set(v): if movement_component: movement_component.wall_release_duration = v
var wall_min_foot_below_hip: float:
	get: return movement_component.wall_min_foot_below_hip if movement_component else 5.0
	set(v): if movement_component: movement_component.wall_min_foot_below_hip = v
var wall_max_foot_lag: float:
	get: return movement_component.wall_max_foot_lag if movement_component else 7.0
	set(v): if movement_component: movement_component.wall_max_foot_lag = v
var wall_hang_duration: float:
	get: return movement_component.wall_hang_duration if movement_component else 0.24
	set(v): if movement_component: movement_component.wall_hang_duration = v
var wall_stick_speed: float:
	get: return movement_component.wall_stick_speed if movement_component else 18.0
	set(v): if movement_component: movement_component.wall_stick_speed = v
var wall_grab_upward_limit: float:
	get: return movement_component.wall_grab_upward_limit if movement_component else 85.0
	set(v): if movement_component: movement_component.wall_grab_upward_limit = v

func is_wall_attached() -> bool:
	return movement_component.is_wall_attached() if movement_component else false

func is_wall_jump_action() -> bool:
	return movement_component.is_wall_jump_action() if movement_component else false

func wall_plane_local_x() -> float:
	return movement_component.wall_plane_local_x() if movement_component else 10.0

func _reset_wall_runtime() -> void:
	if movement_component:
		movement_component.reset_wall_runtime()

func _detach_wall_pose_for_reaction() -> void:
	if movement_component:
		movement_component.detach_wall_pose_for_reaction()
	if is_instance_valid(pose_composer) and pose_composer.wall_composer:
		pose_composer.wall_composer.reset()

func update_jump_animation() -> void:
	var clip: StringName = &""
	if wall_action != &"None":
		jump_phase = wall_action
		match wall_action:
			&"WallHang": clip = &"Wall/Hang"
			&"WallSlide": clip = &"Wall/Slide"
			&"WallPush": clip = &"Wall/Push"
			&"WallRelease": clip = &"Wall/Release"
	elif jump_squat_left > 0: jump_phase = &"JumpSquat"
	elif not is_on_floor():
		if velocity.y < 0 and air_time < takeoff_duration: jump_phase = &"Takeoff"
		elif velocity.y < -apex_threshold: jump_phase = &"Rise"
		elif absf(velocity.y) <= apex_threshold: jump_phase = &"Apex"
		else: jump_phase = &"Fall"
	elif landing_left > 0:
		jump_phase = &"Recovery" if landing_left <= landing_recovery_duration else StringName(String(landing_animation).get_slice("/",1))
	else: jump_phase = &"Grounded"
	if jump_phase != &"Grounded" and clip == &"": clip = StringName("Air/"+String(jump_phase))
	if is_on_floor() and landing_left > 0 and jump_squat_left <= 0: clip = landing_animation
	if clip != &"" and anim_player.current_animation != clip:
		anim_player.play(clip,0.025)
	# A finished non-looping clip clears current_animation. Reconcile the desired
	# grounded clip directly, including an empty/stopped player after landing.
	elif clip == &"" and state in [&"Idle",&"Walk",&"Run"] and (anim_player.current_animation != get_state_animation(state) or not anim_player.is_playing()):
		anim_player.play(get_state_animation(state),0.09)
		if state in [&"Walk",&"Run"]: anim_player.seek(grounded_resume_phase*anim_player.current_animation_length,true)
@export var score_profile: EnemyScoreProfile
@export var score_credit_enabled := false
@export var score_combat_power := 1.0
var score_life_id := 0
var score_attack_serial := 0
@export var player_controlled := true
var intent_component: IntentComponent = IntentComponentScript.new()
@export var move_speed := 105.0
@export_range(0.1, 0.9) var walk_speed_ratio := 0.43
@export var acceleration := 700.0
@export var gravity := 650.0
@export var jump_velocity := -245.0
@export var attack_duration := 0.62
@export var max_health := 100.0
@export var allow_air_attack := true
@export_range(0.1,1.0) var attack_movement_multiplier := 1.0
var health := 100.0
var state: StringName = &"Idle"
var attack_time := 0.0
var _facing := 1.0
var facing: float:
	get: return movement_component.facing if movement_component else _facing
	set(v):
		_facing = v
		if movement_component: movement_component.facing = v

var _move_intent := 0.0
var move_intent: float:
	get: return movement_component.move_intent if movement_component else _move_intent
	set(v):
		_move_intent = v
		if movement_component: movement_component.move_intent = v

var _land_time := 0.0
var land_time: float:
	get: return movement_component.land_time if movement_component else _land_time
	set(v):
		_land_time = v
		if movement_component: movement_component.land_time = v
var jump_requested := false
var attack_requested := false
@export var punch_animations := PackedStringArray(["Punch/Attack_1", "Punch/Attack_2", "Punch/Attack_3"])
@export var punch_windows: Array[Vector2] = [Vector2(0.06, 0.18), Vector2(0.08, 0.22), Vector2(0.10, 0.26)]
@export var punch_damages: Array[float] = [7.0, 9.0, 12.0]
@export var punch_impacts: Array[float] = [0.50, 0.75, 1.30]
@export var punch_combo_buffer_start := 0.12
@export var enable_camera_shake := false
var punch_hit_targets: Array[int] = []
var punch_hitbox: Area2D
var punch_collision_shape: CollisionShape2D

var combo_stage := 0
var combo_queued := false
var action_state: StringName = &"None"
var pose_composer: MudPoseComposer

@export var max_stability := 100.0
var stability := 100.0
@export var stability_recovery_rate := 25.0
@export var stability_recovery_cooldown := 0.5
var stability_cooldown_timer := 0.0

var reaction_state: StringName = &"None"
var reaction_time := 0.0
var reaction_duration := 0.0
var reaction_direction := Vector2.RIGHT
var reaction_intensity := 1.0
var reaction_region: StringName = &"UPPER_TORSO"
var reaction_impact_local := Vector2.ZERO
var local_time_scale := 1.0
@export_group("Hit Flash")
@export_range(0.01, 0.30, 0.005) var hit_flash_duration := 0.090
@export_range(0.0, 1.0, 0.05) var hit_flash_peak := 0.95
@export var hit_flash_color := Color.WHITE
var hit_flash_remaining := 0.0
var _hit_flash_total := 0.0
var _hit_flash_active_peak := 0.0
var hit_drag_timer := 0.0
var hit_drag_ratio := 0.40
var reaction_push_offset := Vector2.ZERO

func has_reaction() -> bool:
	return reaction_state != &"None" and reaction_time < reaction_duration

var block_requested := false
@export var guard_movement_multiplier := 0.45

func is_blocking() -> bool:
	return block_requested and state != &"Dead" and not is_attacking() and reaction_state not in [&"HeavyHit", &"Knockdown"]

func is_attacking() -> bool:
	return action_state.begins_with("Attack")

## Unified local-time seam used by HitstopManager. Animation playback is manual
## in this character, while movement/combat/SDF all consume the scaled delta.
func set_local_time_scale(scale: float) -> void:
	local_time_scale = maxf(scale, 0.0)
	if anim_player:
		anim_player.speed_scale = local_time_scale

func attack_animation() -> StringName:
	if is_armed():
		if weapons.current.weapon_class == "blade" and combo_stage < weapons.current.attack_animations.size():
			return StringName(weapons.current.attack_animations[combo_stage])
		return &"Attack"
	if combo_stage < punch_animations.size():
		var punch_name := StringName(punch_animations[combo_stage])
		if anim_player and anim_player.has_animation(punch_name):
			return punch_name
	return &"Attack"

func start_attack(stage: int = 0) -> void:
	score_attack_serial += 1
	combo_stage = stage
	combo_queued = false
	attack_time = 0.0
	action_state = StringName("Attack%d" % (stage+1))
	attack_duration = anim_player.get_animation(attack_animation()).length
	if is_armed():
		weapons.current.begin_attack(stage)
	else:
		punch_hit_targets.clear()
		if punch_hitbox:
			punch_hitbox.monitoring = false

func cancel_attack_pose() -> void:
	action_state = &"None"
	combo_stage = 0
	combo_queued = false
	attack_requested = false
	if punch_hitbox:
		punch_hitbox.set_deferred("monitoring", false)
	if weapons and weapons.current:
		weapons.current.active = false
		if weapons.current.hitbox:
			weapons.current.hitbox.set_deferred("monitoring", false)

func clear_transient_pose_state(clear_reaction := true) -> void:
	cancel_attack_pose()
	_reset_wall_runtime()
	jump_squat_left = 0.0
	pending_jump_source = MudMovementAssist.JumpSource.NONE
	hit_drag_timer = 0.0
	impact_accent_offset = Vector2.ZERO
	reaction_push_offset = Vector2.ZERO
	if clear_reaction:
		reaction_state = &"None"
		reaction_time = 0.0
		reaction_duration = 0.0
	if is_instance_valid(pose_composer):
		pose_composer.restore_base()
		pose_composer.reset_transient()
	if is_instance_valid(body_renderer):
		body_renderer.impact_depth = 0.0
		body_renderer.impact_bulge_height = 0.0

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

func advance_attack(delta: float) -> void:
	var rate := 1.0
	if hit_drag_timer > 0.0:
		hit_drag_timer = maxf(0.0, hit_drag_timer - delta)
		rate = 1.0 - hit_drag_ratio
	attack_time += delta * rate
	if attack_time < attack_duration: return
	var max_stages := weapons.current.attack_animations.size() if is_armed() and weapons.current.weapon_class == "blade" else punch_animations.size()
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

func _update_punch_attack(_delta: float) -> void:
	if not punch_hitbox: return
	var window := punch_windows[combo_stage] if combo_stage < punch_windows.size() else Vector2(0.08, 0.20)
	var reach := calculate_punch_reach()
	var req_reach: float = 0.55 if combo_stage == 2 else 0.80
	var active := is_attacking() and not is_armed() and attack_time >= window.x and attack_time <= window.y and reach >= req_reach
	punch_hitbox.monitoring = active
	
	var active_bone: Bone2D = _hand_back_bone if combo_stage == 1 and is_instance_valid(_hand_back_bone) else _hand_front_bone
	if is_instance_valid(active_bone):
		punch_hitbox.global_position = active_bone.global_position + Vector2(facing * 4.0, 0.0)
	else:
		punch_hitbox.global_position = global_position + Vector2(facing * 35.0, -32.0)
		
	if not active: return
	for area in punch_hitbox.get_overlapping_areas():
		_on_punch_area_entered(area)

func _on_punch_area_entered(area: Area2D) -> void:
	if not is_attacking() or is_armed(): return
	var owner_node = area.get_meta("owner_character", null)
	if owner_node == self: return
	var id := area.get_instance_id()
	if punch_hit_targets.has(id): return
	punch_hit_targets.append(id)
	var dmg: float = punch_damages[combo_stage] if combo_stage < punch_damages.size() else 8.0
	var event := HitEvent.new()
	event.attacker = self
	event.attack_name = attack_animation()
	event.attack_token = score_attack_serial
	event.damage = dmg
	event.direction = Vector2(facing, 0.0)
	event.attacker_velocity = velocity
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
	impact_accent_offset = Vector2(-facing * 1.0, 0.0)

	if enable_camera_shake:
		var tree := get_tree()
		if tree and tree.current_scene and tree.current_scene.has_method("trigger_camera_shake"):
			tree.current_scene.call("trigger_camera_shake", event.direction, event.camera_shake_strength, 0.08)

	if area.has_method("receive_hit"):
		area.call("receive_hit", event)
	elif area.get_parent() and area.get_parent().has_method("receive_hit"):
		area.get_parent().call("receive_hit", event)
	if splatter and is_instance_valid(area):
		splatter.burst(area.global_position, 5)

@onready var visual: Node2D = $Visual
@onready var pose_root: Node2D = $Visual/PoseRoot
@onready var local_fx_behind: Node2D = $Visual/LocalFXBehind
@onready var local_fx_body: Node2D = $Visual/LocalFXBody
@onready var local_fx_front: Node2D = $Visual/LocalFXFront

func get_local_fx_socket(channel: StringName) -> Node2D:
	match channel:
		&"Behind", &"BEHIND", &"LOCAL_BEHIND":
			return local_fx_behind
		&"Body", &"BODY", &"LOCAL_BODY":
			return local_fx_body
		&"Front", &"FRONT", &"LOCAL_FRONT":
			return local_fx_front
	return local_fx_body

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var skeleton: Skeleton2D = $Visual/PoseRoot/Skeleton2D
@onready var body_renderer: MudBodyRenderer = $Visual/MudBodyRenderer
@onready var eyes: MudEyeController = $Visual/Eyes
@onready var equipment: EquipmentManager = $Visual/Equipment
@onready var weapons: WeaponManager = $Visual/WeaponSlots
@onready var death_controller: MudDeathController = $DeathController
@onready var splatter: MudPixelSplatter = $Visual/PixelMudSplatter
@onready var death_ascension: MudPixelAscension = $Visual/DeathAscension

var _head_bone: Bone2D
var _upper_arm_front_bone: Bone2D
var _forearm_front_bone: Bone2D
var _hand_front_bone: Bone2D
var _upper_arm_back_bone: Bone2D
var _forearm_back_bone: Bone2D
var _hand_back_bone: Bone2D
var _thigh_front_bone: Bone2D
var _shin_front_bone: Bone2D
var _foot_front_bone: Bone2D
var _thigh_back_bone: Bone2D
var _shin_back_bone: Bone2D
var _foot_back_bone: Bone2D
var _spine_lower_bone: Bone2D
var _spine_upper_bone: Bone2D
var impact_accent_offset: Vector2 = Vector2.ZERO

class RigAdapter extends RefCounted:
	signal foot_contact(side: StringName)
	var character: MudCharacter
	var body_renderer: MudBodyRenderer
	var debug_draw := false
	var stretch := 1.0
	var time := 0.0
	var gait: MudLocomotion = MudLocomotion.new()
	var weapon_angle := 0.0

	func _init() -> void:
		gait.foot_contact.connect(func(side: StringName) -> void:
			foot_contact.emit(side)
		)

	var compressions: Dictionary:
		get: return body_renderer.compressions if body_renderer else {}
	var angles: Dictionary:
		get: return body_renderer.angles if body_renderer else {}
	var segments: Array[MudSegment]:
		get: return body_renderer.segments if body_renderer else []

	func point(id: StringName) -> Vector2:
		return body_renderer.point(id) if body_renderer else Vector2.ZERO

	func pose(delta: float, target_state: StringName, motion: Vector2, _attack_time: float, _land_time: float) -> void:
		time += delta
		if gait:
			gait.advance(delta, motion.x, true, 32.0)
		if character:
			if character.state != target_state:
				character.transition(target_state)
			if character.anim_player:
				if delta > 0.0:
					character.anim_player.advance(delta)
				elif gait:
					var anim_len := character.anim_player.current_animation_length
					if anim_len > 0.0:
						character.anim_player.seek(fmod(gait.phase, 1.0) * anim_len, true)

var rig: RigAdapter
var _contact_squash_timer := 0.0
var _flight_stretch_timer := 0.0

func _ready() -> void:
	add_to_group(&"player_input_entities")
	health = max_health
	if has_node("Components/MovementComponent"):
		movement_component = $Components/MovementComponent
	elif has_node("MovementComponent"):
		movement_component = $MovementComponent
	else:
		movement_component = MovementComponent.new()
		movement_component.name = "MovementComponent"
		var comp_root := get_node_or_null("Components")
		if comp_root:
			comp_root.add_child(movement_component)
		else:
			add_child(movement_component)
	movement_component.setup(self)
	movement_component.movement_state_changed.connect(func(s: StringName) -> void: transition(s))
	movement_component.landed.connect(func(impact: float, hard: bool) -> void:
		landed.emit(impact, hard)
		if anim_player and movement_component.landing_animation != &"":
			movement_component.landing_left = anim_player.get_animation(movement_component.landing_animation).length
	)
	movement_component.wall_action_changed.connect(func(prev: StringName, curr: StringName) -> void:
		wall_action_changed.emit(prev, curr)
		if curr == &"WallHang":
			cancel_attack_pose()
			if is_instance_valid(pose_composer) and pose_composer.wall_composer:
				pose_composer.wall_composer.reset()
	)
	movement_component.wall_jumped.connect(func(dir: Vector2) -> void: wall_jumped.emit(dir))
	movement_component.unfallen_started.connect(func(duration: float) -> void: unfallen_started.emit(duration))
	movement_component.unfallen_ended.connect(func() -> void: unfallen_ended.emit())
	movement_component.jump_executed.connect(func(source: MudMovementAssist.JumpSource) -> void: jump_executed.emit(source))
	$Hurtbox.set_meta("owner_character", self)
	weapons.owner_character = self
	if weapons.current: weapons.current.set_meta("owner_character", self)
	rig = RigAdapter.new()
	rig.character = self
	rig.body_renderer = body_renderer
	rig.foot_contact.connect(func(side: StringName) -> void:
		footstep.emit(side)
		_contact_squash_timer = 2.0 / 60.0
	)
	footstep.connect(func(_side: StringName) -> void:
		_contact_squash_timer = 2.0 / 60.0
	)
	if skeleton:
		_head_bone = skeleton.get_node_or_null("Pelvis/Torso/Head") as Bone2D
		_upper_arm_front_bone = skeleton.get_node_or_null("Pelvis/Torso/UpperArmFront") as Bone2D
		_forearm_front_bone = skeleton.get_node_or_null("Pelvis/Torso/UpperArmFront/ForearmFront") as Bone2D
		_hand_front_bone = skeleton.get_node_or_null("Pelvis/Torso/UpperArmFront/ForearmFront/HandFront") as Bone2D
		_upper_arm_back_bone = skeleton.get_node_or_null("Pelvis/Torso/UpperArmBack") as Bone2D
		_forearm_back_bone = skeleton.get_node_or_null("Pelvis/Torso/UpperArmBack/ForearmBack") as Bone2D
		_hand_back_bone = skeleton.get_node_or_null("Pelvis/Torso/UpperArmBack/ForearmBack/HandBack") as Bone2D
		_thigh_front_bone = skeleton.get_node_or_null("Pelvis/ThighFront") as Bone2D
		if _thigh_front_bone:
			_shin_front_bone = _thigh_front_bone.get_node_or_null("ShinFront") as Bone2D
			if _shin_front_bone:
				_foot_front_bone = _shin_front_bone.get_node_or_null("FootFront") as Bone2D
		_thigh_back_bone = skeleton.get_node_or_null("Pelvis/ThighBack") as Bone2D
		if _thigh_back_bone:
			_shin_back_bone = _thigh_back_bone.get_node_or_null("ShinBack") as Bone2D
			if _shin_back_bone:
				_foot_back_bone = _shin_back_bone.get_node_or_null("FootBack") as Bone2D
		_spine_lower_bone = skeleton.get_node_or_null("Pelvis/SpineLower") as Bone2D
		if _spine_lower_bone:
			_spine_upper_bone = _spine_lower_bone.get_node_or_null("SpineUpper") as Bone2D
		assert(is_instance_valid(_spine_lower_bone) and is_instance_valid(_spine_upper_bone), "Spine deformation bones must be authored in mud_character.tscn")
	punch_hitbox = Area2D.new()
	punch_hitbox.name = "PunchHitbox"
	punch_hitbox.collision_layer = 0
	punch_hitbox.collision_mask = 4
	punch_hitbox.monitoring = false
	punch_hitbox.monitorable = false
	punch_hitbox.set_meta("owner_character", self)
	punch_collision_shape = CollisionShape2D.new()
	var punch_box := RectangleShape2D.new()
	punch_box.size = Vector2(20, 16)
	punch_collision_shape.shape = punch_box
	punch_hitbox.add_child(punch_collision_shape)
	punch_hitbox.area_entered.connect(_on_punch_area_entered)
	add_child(punch_hitbox)
	if death_controller:
		death_controller.character = self
	if anim_player:
		anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		anim_player.play(&"Idle")
	pose_composer = MudPoseComposer.new()
	pose_composer.character = self
	pose_composer.blade_footwork = blade_footwork
	pose_composer.z_index = 20
	add_child(pose_composer)
	pose_composer.evaluate(0.0)
	_sync_visual(0)

## Shared input seam: AI / NPC controllers use this without modifying the rig.
func set_intent(direction: float, jump := false, attack := false, block := false) -> void:
	if state == &"Dead": return
	intent_component.move_direction = clampf(direction, -1, 1)
	intent_component.jump_pressed = jump
	intent_component.attack_pressed = attack
	intent_component.block_held = block
	move_intent = intent_component.move_direction
	if movement_component:
		movement_component.set_move_intent(move_intent)
		if jump:
			movement_component.jump()
	jump_requested = jump_requested or jump
	attack_requested = attack_requested or attack
	block_requested = block

func obtain_item(item: CoyoteItem) -> void:
	if movement_component: movement_component.obtain_item(item)

func remove_item(item_id: StringName) -> void:
	if movement_component: movement_component.remove_item(item_id)

func obtain_content_item(content_id: StringName) -> bool:
	return movement_component.obtain_content_item(content_id) if movement_component else false

func is_unfallen() -> bool:
	return movement_component.is_unfallen() if movement_component else false

func _draw() -> void:
	if movement_assist_debug and is_unfallen():
		draw_line(Vector2(-6.0, 3.0), Vector2(6.0, 3.0), Color(1.0, 1.0, 1.0, 0.72), 1.0)
		draw_arc(Vector2.ZERO, 4.0, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.58), 1.0)

func has_active_coyote_window() -> bool:
	return movement_component.has_active_coyote_window() if movement_component else false

func get_effective_coyote_time() -> float:
	return movement_component.get_effective_coyote_time() if movement_component else 0.0

func get_effective_jump_buffer_time() -> float:
	return movement_component.get_effective_jump_buffer_time() if movement_component else 0.0

func _perform_jump(source: MudMovementAssist.JumpSource) -> void:
	if movement_component:
		movement_component.perform_jump(source)

func die() -> void:
	if state == &"Dead": return
	move_intent = 0.0
	block_requested = false
	clear_transient_pose_state()
	punch_hit_targets.clear()
	landing_left = 0.0
	air_time = 0.0
	jump_phase = &"Grounded"
	pose_composer.base_pose.clear()
	jump_requested = false
	pending_jump_source = MudMovementAssist.JumpSource.NONE
	movement_assist.reset(false)
	attack_requested = false
	transition(&"Dead")
	if anim_player:
		anim_player.stop()
	if death_controller:
		death_controller.start_death()
	velocity = Vector2.ZERO
	var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)

func rise() -> void:
	score_life_id += 1
	if state != &"Dead": return
	_clear_managed_hitstop()
	_clear_hit_flash()
	health = max_health
	stability = max_stability
	clear_transient_pose_state()
	move_intent = 0.0
	jump_requested = false
	pending_jump_source = MudMovementAssist.JumpSource.NONE
	movement_assist.reset(false)
	attack_requested = false
	velocity = Vector2.ZERO
	if weapons:
		weapons.weapon_dropped = false
		weapons.weapon_grounded = false
		weapons.equip(weapons.default_weapon)
	var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", true)
	if death_controller:
		death_controller.start_rise()

func revive(animated: bool = false) -> void:
	score_life_id += 1
	_clear_managed_hitstop()
	_clear_hit_flash()
	if animated and state == &"Dead":
		rise()
		return
	health = max_health
	stability = max_stability
	clear_transient_pose_state()
	punch_hit_targets.clear()
	landing_left = 0.0
	air_time = 0.0
	jump_phase = &"Grounded"
	pose_composer.base_pose.clear()
	move_intent = 0.0
	jump_requested = false
	pending_jump_source = MudMovementAssist.JumpSource.NONE
	movement_assist.reset(is_on_floor())
	attack_requested = false
	velocity = Vector2.ZERO
	state = &"Idle"
	if death_controller:
		death_controller.reset()
	if skeleton:
		for bone in skeleton.find_children("*", "Bone2D"):
			if bone is Bone2D:
				bone.apply_rest()
	if body_renderer:
		body_renderer.death_progress = 0.0
		body_renderer.death_dissolve = 0.0
	if death_ascension:
		death_ascension.reset()
	if eyes:
		eyes.sync_death(0.0)
	if equipment:
		equipment.sync_death(0.0, true)
	if weapons:
		weapons.weapon_dropped = false
		weapons.weapon_grounded = false
		weapons.equip(weapons.default_weapon)
	if anim_player:
		anim_player.play(&"Idle")
	var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", true)
	_sync_visual(0.0)

func is_armed() -> bool:
	return weapons != null and is_instance_valid(weapons.current)

func is_retreating() -> bool:
	if not is_attacking() or not is_on_floor():
		return false
	if move_intent != 0.0 and facing * move_intent < -0.01:
		return true
	if absf(move_intent) <= 0.01 and facing * velocity.x < -5.0:
		return true
	return false

func get_state_animation(state_name: StringName) -> StringName:
	var anim_name := state_name
	if is_retreating() and state_name in [&"Walk", &"Run"]:
		anim_name = &"Backstep"
	if not is_armed():
		var unarmed_name := StringName(String(anim_name) + "_Unarmed")
		if anim_player and anim_player.has_animation(unarmed_name):
			return unarmed_name
	return anim_name

func sync_weapon_animation() -> void:
	# A new grip starts from the authored animation pose, never stale action IK.
	if is_instance_valid(pose_composer):
		pose_composer.restore_base()
		pose_composer.reset_transient()
	impact_accent_offset = Vector2.ZERO
	if state in [&"Idle", &"Walk", &"Run", &"Jump", &"Fall"]:
		var target_anim := get_state_animation(state)
		if anim_player and anim_player.current_animation != target_anim:
			var prev_len := anim_player.current_animation_length
			var norm_pos := anim_player.current_animation_position / maxf(prev_len, 0.001) if prev_len > 0 else 0.0
			anim_player.play(target_anim, 0.12)
			var next_len := anim_player.current_animation_length
			anim_player.seek(norm_pos * next_len, true)

func transition(next: StringName) -> void:
	if next == &"Attack":
		start_attack()
		return
	if state == next: return
	if state == &"Dead" and next != &"Dead": return
	var previous := state
	state = next
	state_changed.emit(previous, state)
	if anim_player:
		var target_anim := get_state_animation(next)
		# Preserve gait phase between Walk and Run so supporting foot is preserved
		if (previous == &"Walk" or previous == &"Run") and (next == &"Walk" or next == &"Run"):
			if anim_player.current_animation != target_anim:
				var prev_len := anim_player.current_animation_length
				var norm_pos := anim_player.current_animation_position / maxf(prev_len, 0.001) if prev_len > 0 else 0.0
				anim_player.play(target_anim, 0.10)
				var next_len := anim_player.current_animation_length
				anim_player.seek(norm_pos * next_len, true)
		elif next == &"Idle" and (previous == &"Walk" or previous == &"Run"):
			# Settle into idle over 4-6 frames (~0.08 - 0.10s)
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

func _physics_process(delta: float) -> void:
	if not is_node_ready(): return
	_update_hit_flash(delta)
	if local_time_scale <= 0.0:
		if is_instance_valid(pose_composer):
			pose_composer.restore_base()
			pose_composer.evaluate(0.0)
		_sync_visual(0.0)
		return
	delta *= local_time_scale
	if state == &"Dead":
		if death_controller:
			death_controller.update(delta)
		_sync_visual(delta)
		return

	if reaction_time < reaction_duration:
		reaction_time += delta
		if reaction_time >= reaction_duration:
			reaction_state = &"None"
			reaction_push_offset = Vector2.ZERO

	if stability_cooldown_timer > 0.0:
		stability_cooldown_timer = maxf(0.0, stability_cooldown_timer - delta)
	elif stability < max_stability:
		stability = minf(max_stability, stability + stability_recovery_rate * delta)

	if is_instance_valid(pose_composer):
		pose_composer.restore_base()

	var grounded := is_on_floor()
	var allow_coyote_departure := reaction_state not in [&"HeavyHit", &"Knockdown"]

	if not is_attacking():
		if is_blocking():
			action_state = &"Block"
		elif action_state == &"Block":
			action_state = &"None"

	if grounded and state in [&"Walk",&"Run"] and anim_player.current_animation == get_state_animation(state):
		movement_component.grounded_resume_phase = anim_player.current_animation_position/maxf(anim_player.current_animation_length,.001)

	var atk_mult := 1.0
	if is_attacking():
		if not is_armed():
			var window := punch_windows[combo_stage] if combo_stage < punch_windows.size() else Vector2(0.08, 0.20)
			atk_mult = 0.85 if (attack_time >= window.x and attack_time <= window.y) else 0.95
		else:
			atk_mult = attack_movement_multiplier
	elif is_blocking():
		atk_mult = guard_movement_multiplier
	if reaction_state in [&"HeavyHit", &"Knockdown"]:
		atk_mult *= 0.35

	if attack_requested:
		if not is_attacking() and (grounded or allow_air_attack):
			start_attack()
		elif is_attacking():
			var buffer_start := weapons.current.combo_buffer_start if (is_armed() and weapons.current) else punch_combo_buffer_start
			if attack_time >= attack_duration * buffer_start:
				combo_queued = true
	attack_requested = false

	var is_atk_or_blk := is_attacking() or is_blocking()
	movement_component.physics_step(delta, atk_mult, allow_coyote_departure, is_atk_or_blk, state)
	_contact_squash_timer = maxf(0.0, _contact_squash_timer - delta)
	_flight_stretch_timer = maxf(0.0, _flight_stretch_timer - delta)
	if not is_on_floor() and velocity.y < 0:
		_flight_stretch_timer = 2.0 / 60.0
	if rig and rig.gait:
		rig.gait.advance(delta, velocity.x, is_on_floor() and absf(velocity.x) > 5, 32.0)
		if is_on_floor() and state == &"Run" and rig.gait.phase_label() == "Flight":
			_flight_stretch_timer = 2.0 / 60.0
	if is_attacking():
		advance_attack(delta)
	if not is_on_floor(): transition(&"Jump" if velocity.y < 0 else &"Fall")
	elif absf(velocity.x) <= 5 and move_intent == 0.0: transition(&"Idle")
	else: transition(&"Walk" if absf(velocity.x) <= move_speed * 0.6 else &"Run")
	update_jump_animation()
	if is_instance_valid(pose_composer):
		pose_composer.evaluate(delta)
	_sync_visual(delta)

func _sync_visual(delta: float) -> void:
	if not is_instance_valid(visual) or not is_instance_valid(body_renderer): return
	if movement_assist_debug: queue_redraw()
	if rig:
		body_renderer.modifier_debug_draw = rig.debug_draw
	impact_accent_offset = impact_accent_offset.move_toward(Vector2.ZERO, delta * 30.0)
	reaction_push_offset = reaction_push_offset.move_toward(Vector2.ZERO, delta * 24.0)
	# Only the visual origin is snapped, never the physics body or FK anchors.
	visual.position = global_position.round() - global_position
	# Biomechanically stable skeleton: do NOT scale skeletal limb lengths
	visual.scale = Vector2(facing, 1.0)
	# Legacy Front bones are anatomical RIGHT; Back bones are anatomical LEFT.
	# Mirroring changes visual depth, never which hand owns the sword/accessory.
	var right_depth := facing
	if is_armed() and is_attacking():
		right_depth = weapons.blade_depth if combo_stage == 1 else (-1.0 if attack_time < .18 else 1.0)
	elif is_armed() and is_blocking(): right_depth = 1.0
	body_renderer.facing_depth = facing
	body_renderer.weapon_arm_depth = right_depth
	body_renderer.offhand_arm_depth = -facing
	if is_instance_valid(weapons):
		weapons.hand_depth = right_depth
	if state == &"Dead" and death_controller:
		body_renderer.death_progress = death_controller.death_progress
		body_renderer.death_dissolve = death_controller.dissolve_progress()
		body_renderer.puddle_spread_ratio = death_controller.puddle_spread_ratio
		body_renderer.limb_retraction_strength = death_controller.limb_retraction_strength
		body_renderer.torso_squash_ratio = death_controller.torso_squash_ratio
		body_renderer.sync_skeleton(skeleton, delta)
		eyes.sync_bone(_head_bone, delta, 0.0)
		eyes.sync_death(death_controller.death_progress, int(death_controller.eye_death_mode))
		equipment.sync_bones(_head_bone, _forearm_front_bone, _hand_front_bone)
		equipment.sync_death(death_controller.death_progress, death_controller.embed_equipment)
		weapons.sync_bone(_hand_front_bone, _forearm_front_bone, attack_time, false, delta)
	else:
		body_renderer.death_progress = 0.0
		body_renderer.death_dissolve = 0.0
		if has_reaction():
			body_renderer.impact_center = reaction_impact_local
			body_renderer.impact_radius = 8.5
			var opp_offset := reaction_direction.x * facing * 12.0
			body_renderer.impact_bulge_center = reaction_impact_local + Vector2(opp_offset, 0.0)
			body_renderer.impact_bulge_radius = 7.5
			var progress: float = clampf(reaction_time / maxf(reaction_duration, 0.001), 0.0, 1.0)
			body_renderer.impact_depth = lerpf(3.2 * reaction_intensity, 0.0, progress)
			body_renderer.impact_bulge_height = lerpf(1.8 * reaction_intensity, 0.0, progress)
			body_renderer.impact_ripple_phase += delta * 4.5
		else:
			body_renderer.impact_depth = move_toward(body_renderer.impact_depth, 0.0, delta * 20.0)
			body_renderer.impact_bulge_height = move_toward(body_renderer.impact_bulge_height, 0.0, delta * 20.0)
		body_renderer.sync_skeleton(skeleton, delta)
		eyes.sync_bone(_head_bone, delta, absf(move_intent))
		eyes.sync_death(0.0)
		equipment.sync_bones(_head_bone, _forearm_front_bone, _hand_front_bone)
		equipment.sync_death(0.0, true)
		weapons.sync_bone(_hand_front_bone, _forearm_front_bone, attack_time, is_attacking(), delta)
		if not is_armed():
			_update_punch_attack(delta)
	if is_instance_valid(equipment):
		equipment.sync_handedness(_forearm_back_bone,_hand_back_bone,right_depth,-facing)
func _get_kill_score() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().get_first_node_in_group(&"score_system")
	return null

func receive_hit(hit_data: Variant) -> void:
	if state == &"Dead": return
	var event: HitEvent
	if hit_data is HitEvent:
		event = hit_data
	elif hit_data is float or hit_data is int:
		event = HitEvent.from_damage(float(hit_data), Vector2(-facing, 0.0))
	elif hit_data is Object and "damage" in hit_data:
		event = HitEvent.from_damage(float(hit_data.damage), Vector2(-facing, 0.0))
	else:
		event = HitEvent.new()
	event.victim = self
	
	# Frontal Block Check
	var is_frontal: bool = (event.direction.x * facing) <= 0.1
	if is_blocking() and is_frontal:
		var block_dmg_mult := 0.15 if is_armed() else 0.35
		var block_poise_mult := 0.30 if is_armed() else 0.50
		var actual_dmg := event.damage * block_dmg_mult
		health = maxf(health - actual_dmg, 0.0)
		event.damage_dealt = actual_dmg
		event.is_blocked = true
		damaged.emit(actual_dmg)
		var ks := _get_kill_score()
		if ks: ks.record_hit(self,event,actual_dmg)
		preload("res://scripts/realm_hit_feedback.gd").emit_hit(self,actual_dmg)
		if health <= 0.0:
			event.is_kill = true
			_request_confirmed_hitstop(event)
			die()
			return
		stability = maxf(0.0, stability - event.poise_damage * block_poise_mult)
		stability_cooldown_timer = stability_recovery_cooldown
		if stability <= 0.0:
			event.is_armor_break = true
			# Guard Broken! Heavy stagger
			reaction_state = &"HeavyHit"
			if event.hit_type not in [&"HeavyHit", &"Knockdown"] and ks: ks.note_heavy_hit(self)
			reaction_time = 0.0
			reaction_duration = 0.45
			reaction_direction = event.direction
			reaction_intensity = 1.8
			reaction_push_offset = event.direction * 3.5
			stability = max_stability * 0.25
			block_requested = false
			cancel_attack_pose()
		else:
			reaction_state = &"BlockHit"
			reaction_time = 0.0
			reaction_duration = 0.20
			reaction_direction = event.direction
			reaction_intensity = 1.0
			# "手臂可以后退，脚不要跟着滑。脚是锚。"
			reaction_push_offset = Vector2.ZERO
			if is_armed():
				if weapons and weapons.current:
					weapons.current.impact_flash_point = global_position + Vector2(facing * 20.0, -23.0)
					weapons.current.impact_flash_timer = 0.05
					weapons.current.queue_redraw()
			elif splatter:
				splatter.burst(global_position + Vector2(facing * 8.0, -32.0), 3)
		_request_confirmed_hitstop(event)
		return

	# A hit reaction owns the pose above Wall IK. Detach before composing the
	# reaction so stale hand targets cannot keep writing the arm chain.
	if wall_action != &"None":
		_detach_wall_pose_for_reaction()
	health = maxf(health - event.damage, 0.0)
	event.damage_dealt = event.damage
	damaged.emit(event.damage)
	var ks := _get_kill_score()
	if ks: ks.record_hit(self,event,event.damage)
	preload("res://scripts/realm_hit_feedback.gd").emit_hit(self,event.damage)
	
	if health <= 0.0:
		event.is_kill = true
		_request_confirmed_hitstop(event)
		die()
		return
		
	# Stability / Poise Processing
	stability = maxf(0.0, stability - event.poise_damage)
	stability_cooldown_timer = stability_recovery_cooldown
	var poise_broken: bool = stability <= 0.0
	event.is_armor_break = poise_broken
	
	# Determine reaction tier
	var tier: StringName = event.hit_type
	if tier == &"Knockdown" or event.poise_damage >= 80.0:
		tier = &"Knockdown"
	elif poise_broken or tier == &"HeavyHit":
		tier = &"HeavyHit"
		# Reset stability after poise break to grant recovery window
		stability = max_stability * 0.35
	elif not is_on_floor():
		tier = &"AirHit"
	elif tier == &"MicroHit":
		tier = &"MicroHit"
	else:
		tier = &"LightHit"
		
	if tier in [&"HeavyHit", &"Knockdown"] and event.hit_type not in [&"HeavyHit", &"Knockdown"]:
		if ks: ks.note_heavy_hit(self)
	reaction_state = tier
	reaction_time = 0.0
	reaction_direction = event.direction
	reaction_region = event.hit_region
	reaction_intensity = clampf(event.impact_force / 80.0, 0.5, 2.2)
	
	# Target Instant Push-First linear displacement along attack direction
	reaction_push_offset = event.direction * event.target_push_distance

	# Local impact position for SDF dent and opposite bulge
	if event.impact_point != Vector2.ZERO:
		reaction_impact_local = to_local(event.impact_point)
	else:
		match reaction_region:
			&"HEAD": reaction_impact_local = Vector2(0.0, -42.0)
			&"LOWER_TORSO", &"LEG": reaction_impact_local = Vector2(0.0, -18.0)
			_: reaction_impact_local = Vector2(0.0, -32.0)
			
	if body_renderer:
		body_renderer.impact_center = reaction_impact_local
		body_renderer.impact_radius = 8.5
		body_renderer.impact_depth = 3.2 * reaction_intensity
		var opp_offset := event.direction.x * facing * 12.0
		body_renderer.impact_bulge_center = reaction_impact_local + Vector2(opp_offset, 0.0)
		body_renderer.impact_bulge_radius = 7.5
		body_renderer.impact_bulge_height = 1.8 * reaction_intensity

	# Durations
	match tier:
		&"MicroHit": reaction_duration = 0.08
		&"LightHit": reaction_duration = 0.15
		&"AirHit": reaction_duration = 0.20
		&"HeavyHit": reaction_duration = 0.35
		&"Knockdown": reaction_duration = 0.48
		_: reaction_duration = 0.15
		
	# Physical knockback impulse (world physics)
	var air_mult: float = 1.25 if not is_on_floor() else 1.0
	velocity += event.direction * (event.impact_force * air_mult)
	if tier == &"Knockdown":
		velocity.y = minf(velocity.y, -180.0)
		
	# Interrupt action on HeavyHit or Knockdown
	if tier in [&"HeavyHit", &"Knockdown"]:
		cancel_attack_pose()
	_request_confirmed_hitstop(event)


func _request_confirmed_hitstop(event: HitEvent) -> void:
	trigger_hit_flash(event)
	var manager := get_node_or_null("/root/HitstopManager")
	if manager:
		manager.request_hitstop(event)


func _clear_managed_hitstop() -> void:
	var manager := get_node_or_null("/root/HitstopManager")
	if manager:
		manager.clear_actor_stop(self)
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
	if body_renderer:
		body_renderer.set_hit_flash(_hit_flash_active_peak, hit_flash_color)


func _update_hit_flash(delta: float) -> void:
	if hit_flash_remaining <= 0.0:
		return
	hit_flash_remaining = maxf(0.0, hit_flash_remaining - delta)
	var weight := pow(hit_flash_remaining / maxf(_hit_flash_total, 0.001), 0.65)
	if body_renderer:
		body_renderer.set_hit_flash(_hit_flash_active_peak * weight, hit_flash_color)
	if hit_flash_remaining == 0.0:
		_hit_flash_total = 0.0
		_hit_flash_active_peak = 0.0


func _clear_hit_flash() -> void:
	hit_flash_remaining = 0.0
	_hit_flash_total = 0.0
	_hit_flash_active_peak = 0.0
	if body_renderer:
		body_renderer.set_hit_flash(0.0, hit_flash_color)
