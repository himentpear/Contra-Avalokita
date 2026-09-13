class_name MudCharacter
extends CharacterBody2D
@export var blade_footwork: Resource = preload("res://resources/blade_footwork.tres")
const HitEvent = preload("res://scripts/hit_event.gd")
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
@export_group("Movement Assist")
@export_range(0.0, 0.40, 0.005) var base_coyote_time := 0.10
@export_range(0.0, 0.30, 0.005) var base_jump_buffer_time := 0.08
@export var movement_assist_debug := false
@export_group("")
var air_time := 0.0
var last_air_velocity_y := 0.0
var jump_phase: StringName = &"Grounded"
var jump_squat_left := 0.0
var landing_left := 0.0
var landing_animation: StringName = &""
var grounded_resume_phase := 0.0
var movement_assist := MudMovementAssist.new()
var item_inventory := MudItemInventory.new()
var pending_jump_source := MudMovementAssist.JumpSource.NONE

@export_group("Wall Movement")
@export var wall_slide_speed := 58.0
@export var wall_hang_duration := 0.24
@export var wall_stick_speed := 18.0
@export var wall_grab_upward_limit := 85.0
@export var wall_jump_horizontal_speed := 185.0
@export var wall_jump_vertical_speed := 238.0
@export var wall_push_duration := 0.075
@export var wall_release_duration := 0.14
@export var wall_regrab_cooldown := 0.18
@export_group("Wall IK")
@export var wall_max_foot_lag := 7.0
@export var wall_min_foot_below_hip := 5.0
@export_group("")
var wall_action: StringName = &"None"
var wall_side := 0.0
var wall_action_time := 0.0
var wall_hang_left := 0.0
var wall_regrab_left := 0.0
var wall_surface_x := INF
var wall_hand_anchor_y := 0.0
var wall_foot_anchor_y := 0.0
var wall_slide_scrape_offset := 0.0
## Knee branch sign locked at hang entry. +1=outward (away from wall), -1=inward, 0=unset.
var wall_front_knee_sign := 0.0
var wall_back_knee_sign := 0.0

func is_wall_attached() -> bool:
	return wall_action in [&"WallHang", &"WallSlide"]

func is_wall_jump_action() -> bool:
	return wall_action in [&"WallPush", &"WallRelease"]

func _set_wall_action(next: StringName) -> void:
	if wall_action == next:
		return
	var previous := wall_action
	wall_action = next
	wall_action_time = 0.0
	wall_action_changed.emit(previous, wall_action)
	# Clear locked knee branch when leaving wall entirely
	if next == &"None" or next == &"WallRelease":
		wall_front_knee_sign = 0.0
		wall_back_knee_sign = 0.0

func _contact_wall_side() -> float:
	if not is_on_wall():
		return 0.0
	var normal := get_wall_normal()
	if absf(normal.x) < 0.7:
		return 0.0
	return -signf(normal.x)

func _can_hold_wall(side: float) -> bool:
	return side != 0.0 and move_intent * side > 0.1 and wall_regrab_left <= 0.0

func _capture_wall_surface(side: float) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		if absf(normal.x) >= 0.7 and is_equal_approx(-signf(normal.x), side):
			wall_surface_x = collision.get_position().x
			return
	if is_inf(wall_surface_x):
		wall_surface_x = global_position.x + side * 10.0

func wall_plane_local_x() -> float:
	if wall_side == 0.0 or is_inf(wall_surface_x):
		return 10.0
	var wall_global := Vector2(wall_surface_x, global_position.y)
	return visual.to_local(wall_global).x

func _enter_wall_hang(side: float) -> void:
	wall_side = side
	facing = side
	_capture_wall_surface(side)
	wall_hand_anchor_y = global_position.y - 51.0
	wall_foot_anchor_y = global_position.y - 22.0
	wall_slide_scrape_offset = 0.0
	wall_hang_left = wall_hang_duration
	velocity.y = 0.0
	action_state = &"None"
	combo_stage = 0
	combo_queued = false
	if is_instance_valid(pose_composer) and pose_composer.wall_composer:
		pose_composer.wall_composer.reset()
	_set_wall_action(&"WallHang")


func _update_wall_before_move(delta: float) -> void:
	wall_regrab_left = maxf(0.0, wall_regrab_left - delta)
	wall_action_time += delta
	if is_on_floor():
		wall_side = 0.0
		wall_hang_left = 0.0
		_set_wall_action(&"None")
		return
	if wall_action == &"WallPush":
		velocity = Vector2(wall_side * wall_stick_speed, 0.0)
		if wall_action_time >= wall_push_duration:
			var launch := Vector2(-wall_side * wall_jump_horizontal_speed, -wall_jump_vertical_speed)
			velocity = launch
			wall_regrab_left = wall_regrab_cooldown
			_set_wall_action(&"WallRelease")
			wall_jumped.emit(launch)
		return
	if wall_action == &"WallRelease":
		if wall_action_time >= wall_release_duration:
			_set_wall_action(&"None")
		return

	var side := _contact_wall_side()
	if not _can_hold_wall(side):
		if is_wall_attached():
			_set_wall_action(&"None")
		return
	if not is_wall_attached():
		if velocity.y >= -wall_grab_upward_limit:
			_enter_wall_hang(side)
		else:
			return

	wall_side = side
	_capture_wall_surface(side)
	facing = side
	velocity.x = wall_side * wall_stick_speed
	if wall_action == &"WallHang":
		wall_hang_left = maxf(0.0, wall_hang_left - delta)
		velocity.y = 0.0
		if wall_hang_left <= 0.0:
			_set_wall_action(&"WallSlide")
	elif wall_action == &"WallSlide":
		# Alternating grip/release friction gives 1-2 px pauses instead of a
		# perfectly uniform vertical translation.
		var scrape_cycle := fmod(wall_action_time, 0.18) / 0.18
		var friction_scale := 0.28 if scrape_cycle < 0.16 else lerpf(0.78, 1.0, scrape_cycle)
		velocity.y = minf(velocity.y, wall_slide_speed * friction_scale)
		wall_hand_anchor_y += velocity.y * delta * 0.24
		wall_hand_anchor_y = maxf(wall_hand_anchor_y, global_position.y - 58.0)
		wall_slide_scrape_offset = sin(wall_action_time * 21.0) * 1.0


func _update_wall_after_move() -> void:
	if is_on_floor():
		wall_side = 0.0
		wall_hang_left = 0.0
		_set_wall_action(&"None")
		return
	if is_wall_attached() or is_wall_jump_action():
		return
	var side := _contact_wall_side()
	if _can_hold_wall(side) and velocity.y >= -wall_grab_upward_limit:
		_enter_wall_hang(side)

func _start_wall_jump() -> void:
	if not is_wall_attached() or wall_side == 0.0:
		return
	movement_assist.suppress_ground_departure()
	movement_assist.jump_buffer_remaining = 0.0
	velocity = Vector2(wall_side * wall_stick_speed, 0.0)
	wall_hang_left = 0.0
	_set_wall_action(&"WallPush")
	jump_phase = &"WallPush"
	air_time = 0.0

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
var land_time := 0.0
var facing := 1.0
var move_intent := 0.0
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
var hit_stop_duration := 0.0
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
	if local_time_scale <= 0.0:
		hit_stop_duration = INF
		hit_stop_ticks = maxi(hit_stop_ticks, 1)
	else:
		hit_stop_duration = 0.0
		hit_stop_ticks = 0

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

func advance_attack(delta: float) -> void:
	if hit_stop_ticks > 0:
		hit_stop_ticks -= 1
		return
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
var hit_stop_ticks: int = 0
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
	health = max_health
	movement_assist.configure(base_coyote_time, base_jump_buffer_time)
	item_inventory.changed.connect(_recompute_movement_modifiers)
	movement_assist.unfallen_started.connect(func(duration: float) -> void: unfallen_started.emit(duration))
	movement_assist.unfallen_ended.connect(func() -> void: unfallen_ended.emit())
	movement_assist.jump_executed.connect(func(source: MudMovementAssist.JumpSource) -> void: jump_executed.emit(source))
	_recompute_movement_modifiers()
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
		else:
			var pelvis := skeleton.get_node_or_null("Pelvis") as Bone2D
			if pelvis:
				_spine_lower_bone = Bone2D.new()
				_spine_lower_bone.name = "SpineLower"
				_spine_lower_bone.position = Vector2(0, -7.33)
				_spine_lower_bone.rest = Transform2D(0.0, Vector2(0, -7.33))
				pelvis.add_child(_spine_lower_bone)
				_spine_upper_bone = Bone2D.new()
				_spine_upper_bone.name = "SpineUpper"
				_spine_upper_bone.position = Vector2(0, -7.33)
				_spine_upper_bone.rest = Transform2D(0.0, Vector2(0, -7.33))
				_spine_lower_bone.add_child(_spine_upper_bone)
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
	move_intent = clampf(direction, -1, 1)
	if jump:
		movement_assist.register_jump_input()
	jump_requested = jump_requested or jump
	attack_requested = attack_requested or attack
	block_requested = block

func _recompute_movement_modifiers() -> void:
	movement_assist.apply_modifiers(item_inventory.aggregate_movement_modifiers())

func obtain_item(item: CoyoteItem) -> void:
	item_inventory.obtain(item)

func remove_item(item_id: StringName) -> void:
	item_inventory.remove(item_id)

func obtain_content_item(content_id: StringName) -> bool:
	if not has_node("/root/ContentRegistry"): return false
	var registry := get_node("/root/ContentRegistry")
	var definition: ContentDefinition = registry.call("get_content", content_id) as ContentDefinition
	if definition == null or not definition.resource is CoyoteItem: return false
	obtain_item(definition.resource as CoyoteItem)
	return true

func is_unfallen() -> bool:
	return movement_assist.is_unfallen()

func _draw() -> void:
	if movement_assist_debug and movement_assist.is_unfallen():
		draw_line(Vector2(-6.0, 3.0), Vector2(6.0, 3.0), Color(1.0, 1.0, 1.0, 0.72), 1.0)
		draw_arc(Vector2.ZERO, 4.0, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.58), 1.0)

func has_active_coyote_window() -> bool:
	return movement_assist.has_active_coyote_window()

func get_effective_coyote_time() -> float:
	return movement_assist.get_effective_coyote_time()

func get_effective_jump_buffer_time() -> float:
	return movement_assist.get_effective_jump_buffer_time()

func _is_coyote_source(source: MudMovementAssist.JumpSource) -> bool:
	return source in [MudMovementAssist.JumpSource.COYOTE, MudMovementAssist.JumpSource.BUFFERED_COYOTE]

func _perform_jump(source: MudMovementAssist.JumpSource) -> void:
	var is_coyote := _is_coyote_source(source)
	var vertical_multiplier := movement_assist.coyote_vertical_jump_multiplier if is_coyote else 1.0
	velocity.y = jump_velocity * vertical_multiplier
	if is_coyote and absf(velocity.x) > 0.01:
		# Boost only launch momentum. Normal aerial acceleration remains responsible
		# for subsequent velocity and pulls it back toward the ordinary speed policy.
		var launch_cap := move_speed * movement_assist.coyote_horizontal_jump_multiplier
		velocity.x = clampf(velocity.x * movement_assist.coyote_horizontal_jump_multiplier, -launch_cap, launch_cap)
	jump_squat_left = 0.0
	landing_left = 0.0
	air_time = 0.0
	pending_jump_source = MudMovementAssist.JumpSource.NONE
	movement_assist.report_jump_executed(source)

func _try_start_assisted_jump(grounded: bool) -> bool:
	var source := movement_assist.resolve_jump_source(grounded)
	if source == MudMovementAssist.JumpSource.NONE:
		return false
	movement_assist.consume_jump(source)
	if source == MudMovementAssist.JumpSource.GROUND:
		pending_jump_source = source
		jump_squat_left = jump_squat_duration
		landing_left = 0.0
		if state in [&"Walk", &"Run"]:
			grounded_resume_phase = anim_player.current_animation_position / maxf(anim_player.current_animation_length, .001)
	else:
		_perform_jump(source)
	return true

func die() -> void:
	if state == &"Dead": return
	move_intent = 0.0
	block_requested = false
	action_state = &"None"
	combo_stage = 0
	combo_queued = false
	if punch_hitbox:
		punch_hitbox.set_deferred("monitoring", false)
	punch_hit_targets.clear()
	jump_squat_left = 0.0
	landing_left = 0.0
	air_time = 0.0
	jump_phase = &"Grounded"
	wall_side = 0.0
	wall_hang_left = 0.0
	wall_regrab_left = 0.0
	_set_wall_action(&"None")
	pose_composer.base_pose.clear()
	jump_requested = false
	pending_jump_source = MudMovementAssist.JumpSource.NONE
	movement_assist.reset(false)
	attack_requested = false
	reaction_state = &"None"
	reaction_time = 0.0
	reaction_duration = 0.0
	hit_stop_duration = 0.0
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
	reaction_state = &"None"
	reaction_time = 0.0
	reaction_duration = 0.0
	hit_stop_duration = 0.0
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
	reaction_state = &"None"
	reaction_time = 0.0
	reaction_duration = 0.0
	hit_stop_duration = 0.0
	action_state = &"None"
	combo_stage = 0
	combo_queued = false
	if punch_hitbox:
		punch_hitbox.monitoring = false
	punch_hit_targets.clear()
	jump_squat_left = 0.0
	landing_left = 0.0
	air_time = 0.0
	jump_phase = &"Grounded"
	wall_side = 0.0
	wall_hang_left = 0.0
	wall_regrab_left = 0.0
	_set_wall_action(&"None")
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

	if stability_cooldown_timer > 0.0:
		stability_cooldown_timer = maxf(0.0, stability_cooldown_timer - delta)
	elif stability < max_stability:
		stability = minf(max_stability, stability + stability_recovery_rate * delta)

	if is_instance_valid(pose_composer):
		pose_composer.restore_base()

	var grounded := is_on_floor()
	var allow_coyote_departure := reaction_state not in [&"HeavyHit", &"Knockdown"] and wall_action == &"None"
	movement_assist.observe_grounded(grounded, allow_coyote_departure)

	if player_controlled:
		var input_direction := Input.get_axis("move_left", "move_right")
		if not Input.is_action_pressed("sprint"): input_direction *= walk_speed_ratio
		var block_pressed := Input.is_action_pressed("block") if InputMap.has_action("block") else false
		set_intent(input_direction, Input.is_action_just_pressed("jump"), Input.is_action_just_pressed("attack"), block_pressed)
		if Input.is_action_just_pressed("equipment"): equipment.toggle()
		if not is_attacking():
			if Input.is_action_just_pressed("weapon_sword"):
				weapons.equip(weapons.default_weapon)
				sync_weapon_animation()
			if Input.is_action_just_pressed("weapon_none"):
				weapons.equip(null)
				sync_weapon_animation()
		if Input.is_action_just_pressed("debug_rig"):
			rig.debug_draw = not rig.debug_draw
			body_renderer.modifier_debug_draw = rig.debug_draw
	
	if not is_attacking():
		if is_blocking():
			action_state = &"Block"
		elif action_state == &"Block":
			action_state = &"None"

	if grounded and state in [&"Walk",&"Run"] and anim_player.current_animation == get_state_animation(state):
		grounded_resume_phase = anim_player.current_animation_position/maxf(anim_player.current_animation_length,.001)
	landing_left = maxf(0.0,landing_left-delta)
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
	velocity.x = move_toward(velocity.x, move_intent * move_speed * atk_mult, acceleration * delta)
	if move_intent != 0 and not is_attacking() and not is_blocking(): facing = signf(move_intent)
	if not grounded: velocity.y += gravity * movement_assist.get_gravity_multiplier() * delta
	_update_wall_before_move(delta)
	if jump_requested and is_wall_attached():
		_start_wall_jump()
	elif jump_squat_left <= 0:
		_try_start_assisted_jump(grounded)
	if jump_squat_left > 0:
		jump_squat_left = maxf(0.0,jump_squat_left-delta)
		if not grounded: jump_squat_left = 0.0
		elif jump_squat_left == 0 and pending_jump_source != MudMovementAssist.JumpSource.NONE:
			_perform_jump(pending_jump_source)
	movement_assist.advance(delta, grounded, allow_coyote_departure)
	if not grounded or velocity.y < 0: last_air_velocity_y = velocity.y
	if attack_requested:
		if not is_attacking() and (grounded or allow_air_attack):
			start_attack()
		elif is_attacking():
			var buffer_start := weapons.current.combo_buffer_start if (is_armed() and weapons.current) else punch_combo_buffer_start
			if attack_time >= attack_duration * buffer_start:
				combo_queued = true
	jump_requested = false
	attack_requested = false
	move_and_slide()
	_update_wall_after_move()
	var grounded_after_move := is_on_floor()
	movement_assist.observe_grounded(grounded_after_move, allow_coyote_departure and wall_action == &"None")
	# A stored input becomes a buffered-ground jump on the exact air-to-ground
	# transition. It launches immediately instead of replaying the normal squat.
	if not grounded and grounded_after_move:
		_try_start_assisted_jump(true)
	movement_assist.finish_step()
	land_time = maxf(0, land_time - delta)
	_contact_squash_timer = maxf(0.0, _contact_squash_timer - delta)
	_flight_stretch_timer = maxf(0.0, _flight_stretch_timer - delta)
	if not grounded and is_on_floor():
		if air_time >= minimum_landing_air_time and last_air_velocity_y >= soft_landing_speed:
			var hard := last_air_velocity_y >= hard_landing_speed
			jump_phase = &"HardLand" if hard else &"SoftLand"
			landing_animation = StringName("Air/"+String(jump_phase))
			landing_left = anim_player.get_animation(landing_animation).length
			landed.emit(last_air_velocity_y,hard)
		air_time = 0.0
	elif not is_on_floor(): air_time += delta
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
			action_state = &"None"
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
		action_state = &"None"
		combo_stage = 0
		combo_queued = false
		if punch_hitbox:
			punch_hitbox.monitoring = false
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
