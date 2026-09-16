class_name MudCharacter
extends CharacterBody2D
@export var blade_footwork: Resource = preload("res://resources/blade_footwork.tres")
const HitEvent = preload("res://scripts/hit_event.gd")
const IntentComponentScript = preload("res://gameplay/components/movement/intent_component.gd")
const MovementComponent = preload("res://scripts/components/movement_component.gd")
const HealthComponent = preload("res://scripts/components/health_component.gd")
const CombatComponent = preload("res://scripts/components/combat_component.gd")
const AnimationController = preload("res://scripts/components/animation_controller.gd")
const MudAnimationContextProviderScript = preload("res://scripts/characters/mud/mud_animation_context_provider.gd")
const MudAnimationProfileResource = preload("res://characters/mud/animation/mud_animation_profile.tres")
const SDFBodyComponent = preload("res://scripts/components/sdf_body_component.gd")
const CharacterStateComponent = preload("res://scripts/components/character_state_component.gd")
const EquipmentController = preload("res://scripts/components/equipment_controller.gd")
const WeaponManager = preload("res://scripts/weapon_manager.gd")
const EquipmentManager = preload("res://scripts/equipment_manager.gd")
const WeaponData = preload("res://scripts/resources/weapon_data.gd")
const CombatSystem = preload("res://scripts/systems/combat_system.gd")
const DamageSystem = preload("res://scripts/systems/damage_system.gd")
const HitstopSystem = preload("res://scripts/systems/hitstop_system.gd")
const CharacterLightingControllerScript = preload("res://scripts/presentation/lighting/character_lighting_controller.gd")
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
var health_component: HealthComponent
var combat_component: CombatComponent
var animation_controller: AnimationController
var animation_context_provider: MudAnimationContextProvider
var animation_profile: CharacterAnimationProfile
var sdf_body_component: SDFBodyComponent
var character_state_component: CharacterStateComponent
var equipment_controller: EquipmentController
var lighting_controller: CharacterLightingControllerScript

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
	if animation_controller:
		animation_controller.update_jump_animation()
@export var score_profile: EnemyScoreProfile
@export var score_credit_enabled := false
@export var score_combat_power := 1.0
var score_life_id: int:
	get: return combat_component.score_life_id if combat_component else 0
	set(v): if combat_component: combat_component.score_life_id = v
var score_attack_serial: int:
	get: return combat_component.score_attack_serial if combat_component else 0
	set(v): if combat_component: combat_component.score_attack_serial = v
@export var player_controlled := true
var intent_component: IntentComponent = IntentComponentScript.new()
@export var move_speed := 105.0
@export_range(0.1, 0.9) var walk_speed_ratio := 0.43
@export var acceleration := 700.0
@export var gravity := 650.0
@export var jump_velocity := -245.0
@export var attack_duration := 0.62:
	get: return combat_component.attack_duration if combat_component else _attack_duration
	set(v):
		_attack_duration = v
		if combat_component: combat_component.attack_duration = v
var _attack_duration := 0.62
@export var max_health := 100.0
@export var allow_air_attack := true:
	get: return combat_component.allow_air_attack if combat_component else _allow_air_attack
	set(v):
		_allow_air_attack = v
		if combat_component: combat_component.allow_air_attack = v
var _allow_air_attack := true
@export_range(0.1,1.0) var attack_movement_multiplier := 1.0:
	get: return combat_component.attack_movement_multiplier if combat_component else _attack_movement_multiplier
	set(v):
		_attack_movement_multiplier = v
		if combat_component: combat_component.attack_movement_multiplier = v
var _attack_movement_multiplier := 1.0
var _health := 100.0
var health: float:
	get: return health_component.health if health_component else _health
	set(v):
		_health = v
		if health_component: health_component.health = v
var _state: StringName = &"Idle"
var state: StringName:
	get: return character_state_component.locomotion_state if character_state_component else _state
	set(v):
		_state = v
		if character_state_component: character_state_component.locomotion_state = v
var attack_time: float:
	get: return combat_component.attack_time if combat_component else 0.0
	set(v): if combat_component: combat_component.attack_time = v
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
var attack_requested: bool:
	get: return combat_component.attack_requested if combat_component else _attack_requested
	set(v):
		_attack_requested = v
		if combat_component: combat_component.attack_requested = v
var _attack_requested := false
@export var punch_animations := PackedStringArray(["Punch/Attack_1", "Punch/Attack_2", "Punch/Attack_3"]):
	get: return combat_component.punch_animations if combat_component else _punch_animations
	set(v):
		_punch_animations = v
		if combat_component: combat_component.punch_animations = v
var _punch_animations := PackedStringArray(["Punch/Attack_1", "Punch/Attack_2", "Punch/Attack_3"])
@export var punch_windows: Array[Vector2] = [Vector2(0.06, 0.18), Vector2(0.08, 0.22), Vector2(0.10, 0.26)]:
	get: return combat_component.punch_windows if combat_component else _punch_windows
	set(v):
		_punch_windows = v
		if combat_component: combat_component.punch_windows = v
var _punch_windows: Array[Vector2] = [Vector2(0.06, 0.18), Vector2(0.08, 0.22), Vector2(0.10, 0.26)]
@export var punch_damages: Array[float] = [7.0, 9.0, 12.0]:
	get: return combat_component.punch_damages if combat_component else _punch_damages
	set(v):
		_punch_damages = v
		if combat_component: combat_component.punch_damages = v
var _punch_damages: Array[float] = [7.0, 9.0, 12.0]
@export var punch_impacts: Array[float] = [0.50, 0.75, 1.30]:
	get: return combat_component.punch_impacts if combat_component else _punch_impacts
	set(v):
		_punch_impacts = v
		if combat_component: combat_component.punch_impacts = v
var _punch_impacts: Array[float] = [0.50, 0.75, 1.30]
@export var punch_combo_buffer_start := 0.12:
	get: return combat_component.punch_combo_buffer_start if combat_component else _punch_combo_buffer_start
	set(v):
		_punch_combo_buffer_start = v
		if combat_component: combat_component.punch_combo_buffer_start = v
var _punch_combo_buffer_start := 0.12
@export var enable_camera_shake := false:
	get: return combat_component.enable_camera_shake if combat_component else _enable_camera_shake
	set(v):
		_enable_camera_shake = v
		if combat_component: combat_component.enable_camera_shake = v
var _enable_camera_shake := false
var punch_hit_targets: Array[int]:
	get: return combat_component.punch_hit_targets if combat_component else []
var punch_hitbox: Area2D:
	get: return combat_component.punch_hitbox if combat_component else null
var punch_collision_shape: CollisionShape2D:
	get: return combat_component.punch_collision_shape if combat_component else null

var combo_stage: int:
	get: return combat_component.combo_stage if combat_component else 0
	set(v): if combat_component: combat_component.combo_stage = v
var combo_queued: bool:
	get: return combat_component.combo_queued if combat_component else false
	set(v): if combat_component: combat_component.combo_queued = v
var action_state: StringName:
	get: return combat_component.action_state if combat_component else &"None"
	set(v): if combat_component: combat_component.action_state = v
var pose_composer: MudPoseComposer

@export var max_stability := 100.0
var _stability := 100.0
var stability: float:
	get: return health_component.stability if health_component else _stability
	set(v):
		_stability = v
		if health_component: health_component.stability = v
@export var stability_recovery_rate := 25.0
@export var stability_recovery_cooldown := 0.5
var stability_cooldown_timer: float:
	get: return health_component.stability_cooldown_timer if health_component else 0.0
	set(v): if health_component: health_component.stability_cooldown_timer = v

func damage(amount: float) -> void:
	if health_component: health_component.damage(amount)

func heal(amount: float) -> void:
	if health_component: health_component.heal(amount)

var reaction_state: StringName:
	get: return combat_component.reaction_state if combat_component else &"None"
	set(v): if combat_component: combat_component.reaction_state = v
var reaction_time: float:
	get: return combat_component.reaction_time if combat_component else 0.0
	set(v): if combat_component: combat_component.reaction_time = v
var reaction_duration: float:
	get: return combat_component.reaction_duration if combat_component else 0.0
	set(v): if combat_component: combat_component.reaction_duration = v
var reaction_direction: Vector2:
	get: return combat_component.reaction_direction if combat_component else Vector2.RIGHT
	set(v): if combat_component: combat_component.reaction_direction = v
var reaction_intensity: float:
	get: return combat_component.reaction_intensity if combat_component else 1.0
	set(v): if combat_component: combat_component.reaction_intensity = v
var reaction_region: StringName:
	get: return combat_component.reaction_region if combat_component else &"UPPER_TORSO"
	set(v): if combat_component: combat_component.reaction_region = v
var reaction_impact_local: Vector2:
	get: return combat_component.reaction_impact_local if combat_component else Vector2.ZERO
	set(v): if combat_component: combat_component.reaction_impact_local = v
var local_time_scale: float:
	get: return combat_component.local_time_scale if combat_component else 1.0
	set(v): if combat_component: combat_component.set_local_time_scale(v)
@export_group("Hit Flash")
@export_range(0.01, 0.30, 0.005) var hit_flash_duration := 0.090:
	get: return combat_component.hit_flash_duration if combat_component else _hit_flash_duration
	set(v):
		_hit_flash_duration = v
		if combat_component: combat_component.hit_flash_duration = v
var _hit_flash_duration := 0.090
@export_range(0.0, 1.0, 0.05) var hit_flash_peak := 0.95:
	get: return combat_component.hit_flash_peak if combat_component else _hit_flash_peak
	set(v):
		_hit_flash_peak = v
		if combat_component: combat_component.hit_flash_peak = v
var _hit_flash_peak := 0.95
@export var hit_flash_color := Color.WHITE:
	get: return combat_component.hit_flash_color if combat_component else _hit_flash_color
	set(v):
		_hit_flash_color = v
		if combat_component: combat_component.hit_flash_color = v
var _hit_flash_color := Color.WHITE
var hit_flash_remaining: float:
	get: return combat_component.hit_flash_remaining if combat_component else 0.0
	set(v): if combat_component: combat_component.hit_flash_remaining = v
var hit_drag_timer: float:
	get: return combat_component.hit_drag_timer if combat_component else 0.0
	set(v): if combat_component: combat_component.hit_drag_timer = v
var hit_drag_ratio: float:
	get: return combat_component.hit_drag_ratio if combat_component else 0.40
	set(v): if combat_component: combat_component.hit_drag_ratio = v
var reaction_push_offset: Vector2:
	get: return combat_component.reaction_push_offset if combat_component else Vector2.ZERO
	set(v): if combat_component: combat_component.reaction_push_offset = v

func has_reaction() -> bool:
	return combat_component.has_reaction() if combat_component else false

var block_requested: bool:
	get: return combat_component.block_requested if combat_component else _block_requested
	set(v):
		_block_requested = v
		if combat_component: combat_component.block_requested = v
var _block_requested := false
@export var guard_movement_multiplier := 0.45:
	get: return combat_component.guard_movement_multiplier if combat_component else _guard_movement_multiplier
	set(v):
		_guard_movement_multiplier = v
		if combat_component: combat_component.guard_movement_multiplier = v
var _guard_movement_multiplier := 0.45

func is_blocking() -> bool:
	return combat_component.is_blocking() if combat_component else false

func is_attacking() -> bool:
	return combat_component.is_attacking() if combat_component else false

## Unified local-time seam used by HitstopManager. Animation playback is manual
## in this character, while movement/combat/SDF all consume the scaled delta.
func set_local_time_scale(scale: float) -> void:
	local_time_scale = maxf(scale, 0.0)
	if anim_player:
		anim_player.speed_scale = local_time_scale

func attack_animation() -> StringName:
	return animation_controller.get_attack_animation() if animation_controller else (combat_component.attack_animation() if combat_component else &"Attack")

func attack() -> void:
	if combat_component: combat_component.attack()

func start_attack(stage: int = 0) -> void:
	if is_instance_valid(weapons):
		weapons.update_carry_mode(true, false)
	if combat_component: combat_component.start_attack(stage)

func cancel_attack_pose() -> void:
	if combat_component: combat_component.cancel_attack_pose()

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
	if sdf_body_component:
		sdf_body_component.reset_impact()
	elif is_instance_valid(body_renderer):
		body_renderer.impact_depth = 0.0
		body_renderer.impact_bulge_height = 0.0

func get_arm_extension_ratio(back_arm := false) -> float:
	return combat_component.get_arm_extension_ratio(back_arm) if combat_component else 0.0

func advance_attack(delta: float) -> void:
	if combat_component: combat_component.advance_attack(delta)

func calculate_punch_reach() -> float:
	return combat_component.calculate_punch_reach() if combat_component else 1.0

func _update_punch_attack(delta: float) -> void:
	if combat_component: combat_component.update_punch_attack(delta)

func _on_punch_area_entered(area: Area2D) -> void:
	if combat_component: combat_component._on_punch_area_entered(area)

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
var _torso_bone: Bone2D
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
	var comp_root: Node = get_node_or_null("Components")
	if not comp_root:
		comp_root = Node.new()
		comp_root.name = "Components"
		add_child(comp_root)

	if has_node("Components/CharacterStateComponent"):
		character_state_component = $Components/CharacterStateComponent
	elif has_node("CharacterStateComponent"):
		character_state_component = $CharacterStateComponent
	else:
		character_state_component = CharacterStateComponent.new()
		character_state_component.name = "CharacterStateComponent"
		comp_root.add_child(character_state_component)

	if has_node("Components/HealthComponent"):
		health_component = $Components/HealthComponent
	elif has_node("HealthComponent"):
		health_component = $HealthComponent
	else:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		comp_root.add_child(health_component)
	health_component.setup(max_health, max_stability)
	health_component.damaged.connect(func(amount: float) -> void: damaged.emit(amount))
	health_component.died.connect(func() -> void: die())

	if has_node("Components/MovementComponent"):
		movement_component = $Components/MovementComponent
	elif has_node("MovementComponent"):
		movement_component = $MovementComponent
	else:
		movement_component = MovementComponent.new()
		movement_component.name = "MovementComponent"
		comp_root.add_child(movement_component)
	movement_component.setup(self, character_state_component)
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

	if has_node("Components/CombatComponent"):
		combat_component = $Components/CombatComponent
	elif has_node("CombatComponent"):
		combat_component = $CombatComponent
	else:
		combat_component = CombatComponent.new()
		combat_component.name = "CombatComponent"
		comp_root.add_child(combat_component)
	combat_component.setup(self, character_state_component)
	combat_component.attack_duration = _attack_duration
	combat_component.allow_air_attack = _allow_air_attack
	combat_component.attack_movement_multiplier = _attack_movement_multiplier
	combat_component.guard_movement_multiplier = _guard_movement_multiplier
	combat_component.punch_animations = _punch_animations
	combat_component.punch_windows = _punch_windows
	combat_component.punch_damages = _punch_damages
	combat_component.punch_impacts = _punch_impacts
	combat_component.punch_combo_buffer_start = _punch_combo_buffer_start
	combat_component.enable_camera_shake = _enable_camera_shake
	combat_component.hit_flash_duration = _hit_flash_duration
	combat_component.hit_flash_peak = _hit_flash_peak
	combat_component.hit_flash_color = _hit_flash_color

	$Hurtbox.set_meta("owner_character", self)
	equipment_controller = weapons
	if equipment_controller:
		equipment_controller.owner_character = self
		if equipment:
			equipment_controller.setup_equipment(equipment)
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
		_torso_bone = skeleton.get_node_or_null("Pelvis/Torso") as Bone2D
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
	if death_controller:
		death_controller.character = self
	if anim_player:
		anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		anim_player.play(&"Idle")

	if has_node("Components/AnimationController"):
		animation_controller = $Components/AnimationController
	elif has_node("AnimationController"):
		animation_controller = $AnimationController
	else:
		animation_controller = AnimationController.new()
		animation_controller.name = "AnimationController"
		comp_root.add_child(animation_controller)
	animation_context_provider = MudAnimationContextProviderScript.new()
	animation_context_provider.name = "MudAnimationContextProvider"
	animation_context_provider.configure(self, movement_component, character_state_component, combat_component, equipment_controller)
	animation_profile = MudAnimationProfileResource.duplicate(true) as CharacterAnimationProfile
	var animation_binding := AnimationBinding.new().bind(anim_player, skeleton)
	animation_controller.setup(animation_context_provider, animation_profile, animation_binding)
	animation_controller.presentation_reset_requested.connect(_reset_mud_animation_presentation)
	combat_component.animation_resolver = animation_controller.get_attack_animation

	if has_node("Components/SDFBodyComponent"):
		sdf_body_component = $Components/SDFBodyComponent
	elif has_node("SDFBodyComponent"):
		sdf_body_component = $SDFBodyComponent
	else:
		sdf_body_component = SDFBodyComponent.new()
		sdf_body_component.name = "SDFBodyComponent"
		comp_root.add_child(sdf_body_component)
	sdf_body_component.setup(self, body_renderer)

	combat_component.hit_flash_changed.connect(func(amount: float, color: Color) -> void:
		if sdf_body_component:
			sdf_body_component.set_hit_flash(amount, color)
		elif body_renderer:
			body_renderer.set_hit_flash(amount, color)
		if lighting_controller:
			lighting_controller.context.hit_flash = amount
	)

	if has_node("Visual/CharacterLightingController"):
		lighting_controller = $Visual/CharacterLightingController as CharacterLightingControllerScript

	pose_composer = MudPoseComposer.new()
	pose_composer.character = self
	pose_composer.blade_footwork = blade_footwork
	pose_composer.z_index = 20
	add_child(pose_composer)
	pose_composer.evaluate(0.0)
	animation_controller.sync_weapon_animation()
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

func perform_jump(source: MudMovementAssist.JumpSource) -> void:
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
	if sdf_body_component:
		sdf_body_component.reset_death()
	elif body_renderer:
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
	return animation_controller.is_retreating() if animation_controller else false

func get_state_animation(state_name: StringName) -> StringName:
	return animation_controller.get_state_animation(state_name) if animation_controller else state_name

func sync_weapon_animation() -> void:
	if animation_controller:
		animation_controller.sync_weapon_animation()

func transition(next: StringName) -> void:
	if next == &"Attack":
		start_attack()
		return
	if state == next or (state == &"Dead" and next != &"Dead"):
		return
	var previous := state
	state = next
	state_changed.emit(previous, next)
	if animation_controller:
		animation_controller.transition(previous, next)

func _reset_mud_animation_presentation() -> void:
	if is_instance_valid(pose_composer):
		pose_composer.restore_base()
		pose_composer.reset_transient()
	impact_accent_offset = Vector2.ZERO

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

	if combat_component:
		combat_component.advance_reaction(delta)

	if health_component:
		health_component.advance_stability(delta)

	if is_instance_valid(pose_composer):
		pose_composer.restore_base()

	var grounded := is_on_floor()
	var allow_coyote_departure := reaction_state not in [&"HeavyHit", &"Knockdown"]

	if combat_component:
		combat_component.handle_block_input()

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

	if combat_component:
		combat_component.handle_attack_input(grounded)
	if is_instance_valid(weapons):
		# Resolve carry once per gameplay frame before locomotion/animation routing.
		# sync_bone performs the transform update later, after the final bone pose.
		weapons.update_carry_mode(is_attacking(), is_blocking())

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
	if sdf_body_component:
		sdf_body_component.facing_depth = facing
		sdf_body_component.weapon_arm_depth = right_depth
		sdf_body_component.offhand_arm_depth = -facing
	else:
		body_renderer.facing_depth = facing
		body_renderer.weapon_arm_depth = right_depth
		body_renderer.offhand_arm_depth = -facing
	if is_instance_valid(weapons):
		weapons.hand_depth = right_depth
	if state == &"Dead" and death_controller:
		if sdf_body_component:
			sdf_body_component.sync_death(death_controller, delta, skeleton)
		else:
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
		weapons.sync_bone(_hand_front_bone, _forearm_front_bone, attack_time, false, delta, _torso_bone)
	else:
		if sdf_body_component:
			sdf_body_component.reset_death()
			sdf_body_component.update_impact_deformation(delta, has_reaction(), reaction_time, reaction_duration, reaction_intensity, reaction_impact_local, reaction_direction, facing)
			sdf_body_component.sync_skeleton(skeleton, delta)
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
		weapons.sync_bone(_hand_front_bone, _forearm_front_bone, attack_time, is_attacking(), delta, _torso_bone)
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
	var event := DamageSystem.normalize_hit_event(hit_data, Vector2(-facing, 0.0))
	event.victim = self
	
	# Frontal Block Check
	var is_frontal: bool = (event.direction.x * facing) <= 0.1
	var block_res := DamageSystem.calculate_block(event, self, is_frontal)
	if block_res["is_blocked"]:
		var actual_dmg: float = block_res["damage"]
		var actual_poise: float = block_res["poise_damage"]
		event.is_blocked = true
		DamageSystem.apply_damage(self, event, actual_dmg)
		if health <= 0.0:
			event.is_kill = true
			_request_confirmed_hitstop(event)
			die()
			return
		stability = maxf(0.0, stability - actual_poise)
		stability_cooldown_timer = stability_recovery_cooldown
		if stability <= 0.0:
			event.is_armor_break = true
			# Guard Broken! Heavy stagger
			reaction_state = &"HeavyHit"
			var ks := _get_kill_score()
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
	DamageSystem.apply_damage(self, event, event.damage)
	
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
	var reaction := CombatSystem.resolve_reaction(event, self, not is_on_floor(), poise_broken)
	var tier: StringName = reaction["tier"]
	if tier == &"HeavyHit" and poise_broken:
		# Reset stability after poise break to grant recovery window
		stability = max_stability * 0.35
		
	var ks := _get_kill_score()
	if tier in [&"HeavyHit", &"Knockdown"] and event.hit_type not in [&"HeavyHit", &"Knockdown"]:
		if ks: ks.note_heavy_hit(self)
	reaction_state = tier
	reaction_time = 0.0
	reaction_direction = event.direction
	reaction_region = event.hit_region
	reaction_intensity = reaction["intensity"]
	reaction_push_offset = reaction["push_offset"]
	reaction_impact_local = reaction["impact_local"]
	reaction_duration = reaction["duration"]
	
	if sdf_body_component:
		sdf_body_component.apply_impact(reaction_impact_local, event.direction, facing, reaction_intensity)
	elif body_renderer:
		body_renderer.impact_center = reaction_impact_local
		body_renderer.impact_radius = 8.5
		body_renderer.impact_depth = 3.2 * reaction_intensity
		var opp_offset := event.direction.x * facing * 12.0
		body_renderer.impact_bulge_center = reaction_impact_local + Vector2(opp_offset, 0.0)
		body_renderer.impact_bulge_radius = 7.5
		body_renderer.impact_bulge_height = 1.8 * reaction_intensity

	# Physical knockback impulse (world physics)
	velocity += CombatSystem.calculate_knockback(event, not is_on_floor())
	if tier == &"Knockdown":
		velocity.y = minf(velocity.y, -180.0)
		
	# Interrupt action on HeavyHit or Knockdown
	if tier in [&"HeavyHit", &"Knockdown"]:
		cancel_attack_pose()
	_request_confirmed_hitstop(event)


func _request_confirmed_hitstop(event: HitEvent) -> void:
	if combat_component:
		combat_component.request_confirmed_hitstop(event)
	else:
		HitstopSystem.request_hitstop(event, self)

func _clear_managed_hitstop() -> void:
	if combat_component:
		combat_component.clear_managed_hitstop()

func trigger_hit_flash(event: HitData = null) -> void:
	if combat_component:
		combat_component.trigger_hit_flash(event)

func _update_hit_flash(delta: float) -> void:
	if combat_component:
		combat_component.update_hit_flash(delta)

func _clear_hit_flash() -> void:
	if combat_component:
		combat_component.clear_hit_flash()
