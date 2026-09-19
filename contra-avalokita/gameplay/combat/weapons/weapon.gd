class_name MudWeapon
extends Node2D
const HitEvent = preload("res://scripts/hit_event.gd")
signal struck(target: Area2D, damage: float)
@export var weapon_name := "Sword"
@export_enum("blade", "other") var weapon_class := "blade"
@export var attack_animations := PackedStringArray(["Blade/Attack_1", "Blade/Attack_2", "Blade/Attack_3"])
@export var attack_windows: Array[Vector2] = [Vector2(.20,.28), Vector2(.16,.25), Vector2(.28,.44)]
@export_range(0.0, 1.0) var combo_buffer_start := 0.15
@export var trail_color := Color(0.88,0.97,1.0,0.85)
@export var trail_lifetime := 0.09
@export var trail_width := 7.0
@export var horizontal_hitbox_size := Vector2(36,13)
@export var horizontal_hitbox_offset := Vector2(25,-42)
var attack_stage := 0
var trail_points: Array[Vector2] = []
var trail_remaining := 0.0
var previous_grip := Vector2.ZERO
var previous_blade := Vector2.ZERO
@export var damage := 10.0
@export var combo_impacts: Array[float] = [0.50, 0.75, 1.30]
@export_enum("punch", "slash", "pierce", "blunt", "bullet", "shotgun", "explosion") var feedback_weapon_type := "slash"
@export var grip_scale := 1.0
@export var stretch_multiplier := 1.0
@export var enable_camera_shake := false
@export var active_start := 0.22
@export var active_end := 0.35
var hit_targets: Array[int] = []
var active := false
var combat_enabled := true
@onready var hitbox: Area2D = $Hitbox
var default_hitbox_transform: Transform2D
var default_shape_transform: Transform2D
var default_hitbox_shape: Shape2D
var slash_shape := RectangleShape2D.new()

func _ready() -> void:
	hitbox.area_entered.connect(_on_area_entered)
	hitbox.monitoring = false
	default_hitbox_transform = hitbox.transform
	default_shape_transform = $Hitbox/CollisionShape2D.transform
	default_hitbox_shape = $Hitbox/CollisionShape2D.shape

func begin_attack(stage: int = 0) -> void:
	attack_stage = stage
	hit_targets.clear()
	trail_points.clear()
	queue_redraw()
	active = false
	hitbox.set_deferred("monitoring", false)

func set_combat_enabled(enabled: bool) -> void:
	if combat_enabled == enabled and (enabled or (trail_remaining <= 0.0 and impact_flash_timer <= 0.0 and trail_points.is_empty())):
		return
	combat_enabled = enabled
	if enabled:
		return
	active = false
	trail_points.clear()
	trail_remaining = 0.0
	impact_flash_timer = 0.0
	queue_redraw()
	if is_instance_valid(hitbox):
		hitbox.set_deferred("monitoring", false)

func update_attack(t: float, attacking: bool) -> void:
	if not combat_enabled:
		set_combat_enabled(false)
		return
	var owner_actor = get_meta("owner_character",null)
	if attacking and weapon_class == "blade" and attack_stage == 1 and is_instance_valid(owner_actor):
		# Combat volume is anchored to the character, independent of projected blade scale.
		slash_shape.size = horizontal_hitbox_size
		$Hitbox/CollisionShape2D.shape = slash_shape
		$Hitbox/CollisionShape2D.transform = Transform2D.IDENTITY
		hitbox.global_transform = owner_actor.visual.global_transform * Transform2D(0,horizontal_hitbox_offset)
	else:
		hitbox.transform = default_hitbox_transform
		$Hitbox/CollisionShape2D.transform = default_shape_transform
		$Hitbox/CollisionShape2D.shape = default_hitbox_shape
	var window := attack_windows[attack_stage] if weapon_class == "blade" and attack_stage < attack_windows.size() else Vector2(active_start,active_end)
	active = attacking and t >= window.x and t <= window.y
	if active:
		var grip: Vector2 = $WeaponGrip.global_position
		var blade: Vector2 = $TrailOrigin.global_position-grip
		if not trail_points.is_empty():
			for sample in range(1,5):
				var weight := sample/4.0
				var angle := lerp_angle(previous_blade.angle(),blade.angle(),weight)
				if attack_stage == 1:
					trail_points.append((previous_grip+previous_blade).lerp(grip+blade,weight))
				else:
					trail_points.append(previous_grip.lerp(grip,weight)+Vector2.from_angle(angle)*lerpf(previous_blade.length(),blade.length(),weight))
		else:
			trail_points.append(grip+blade)
		while trail_points.size() > 24: trail_points.pop_front()
		previous_grip = grip
		previous_blade = blade
		trail_remaining = trail_lifetime
		queue_redraw()
	hitbox.set_deferred("monitoring", active)
	# Recheck overlaps so starting inside a hurtbox still produces one hit.
	if active and hitbox.monitoring:
		for area in hitbox.get_overlapping_areas(): _on_area_entered(area)

var impact_flash_point := Vector2.ZERO
var impact_flash_timer := 0.0

func _process(delta: float) -> void:
	if trail_remaining <= 0.0 and impact_flash_timer <= 0.0:
		return
	trail_remaining = maxf(0.0,trail_remaining-delta)
	if trail_remaining == 0.0: trail_points.clear()
	impact_flash_timer = maxf(0.0, impact_flash_timer - delta)
	queue_redraw()

func _draw_trail() -> void:
	if trail_points.size() < 2: return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var width_scale := 1.0
	var actor = get_meta("owner_character",null)
	if is_instance_valid(actor): width_scale = absf(actor.global_scale.y)
	for i in trail_points.size():
		var tangent := trail_points[mini(i+1,trail_points.size()-1)]-trail_points[maxi(i-1,0)]
		var normal := Vector2(-tangent.y,tangent.x).normalized()
		var u := float(i)/float(trail_points.size()-1)
		var half_width := trail_width*width_scale*.5*pow(sin(PI*u),.65)
		left.append(to_local(trail_points[i]+normal*half_width))
		right.append(to_local(trail_points[i]-normal*half_width))
	right.reverse()
	left.append_array(right)
	var color := trail_color
	color.a *= trail_remaining / maxf(trail_lifetime,.001)
	if left.size() >= 3 and not Geometry2D.triangulate_polygon(left).is_empty():
		draw_colored_polygon(left,color)

func _draw() -> void:
	_draw_trail()
	if impact_flash_timer > 0.0:
		var fp := to_local(impact_flash_point)
		var flash_alpha := clampf(impact_flash_timer / 0.033, 0.0, 1.0)
		var flash_col := Color(1.0, 1.0, 1.0, flash_alpha)
		draw_set_transform(fp,0,Vector2.ONE*.5)
		preload("res://scripts/six_realm_glyphs.gd").draw_symbol(self,posmod(roundi(damage),6),flash_col,2.0)
		draw_set_transform(Vector2.ZERO)

func _on_area_entered(area: Area2D) -> void:
	if not combat_enabled or not active or area.get_meta("owner_character", null) == get_meta("owner_character", null): return
	var id := area.get_instance_id()
	if hit_targets.has(id): return
	hit_targets.append(id)
	struck.emit(area, damage)
	var actor = get_meta("owner_character", null)
	var f := 1.0
	var actor_vel := Vector2.ZERO
	if is_instance_valid(actor):
		if "facing" in actor: f = float(actor.facing)
		if "velocity" in actor: actor_vel = actor.velocity
	var dir := Vector2(f, -0.15).normalized()
	var event := HitEvent.new()
	event.attacker = actor
	if is_instance_valid(actor):
		event.attack_name = actor.attack_animation()
		event.attack_token = actor.score_attack_serial
	event.damage = damage
	event.direction = dir
	event.attacker_velocity = actor_vel
	event.weapon_type = StringName(feedback_weapon_type)
	event.impact = combo_impacts[attack_stage] if attack_stage < combo_impacts.size() else 1.0
	event.hit_index = hit_targets.size() - 1
	event.impact_point = area.global_position if is_instance_valid(area) else global_position
	event.poise_damage = damage * 1.6
	event.impact_force = clampf(damage * 7.5, 70.0, 180.0)
	event.hit_type = &"HeavyHit" if damage >= 20.0 else &"LightHit"
	event.hit_region = &"UPPER_TORSO"
	if event.hit_type == &"HeavyHit":
		event.target_push_distance = 4.0
		event.attacker_drag_ratio = 0.50
		event.camera_shake_strength = 0.0
	else:
		event.target_push_distance = 2.4
		event.attacker_drag_ratio = 0.40
		event.camera_shake_strength = 0.0

	impact_flash_point = event.impact_point
	impact_flash_timer = 0.066

	if is_instance_valid(actor):
		if "hit_drag_timer" in actor:
			actor.hit_drag_timer = 0.10
		if "hit_drag_ratio" in actor:
			actor.hit_drag_ratio = event.attacker_drag_ratio
		if "impact_accent_offset" in actor:
			actor.impact_accent_offset = Vector2(-f * 1.2, 0.0)

	if enable_camera_shake:
		var tree := get_tree()
		if tree and tree.current_scene and tree.current_scene.has_method("trigger_camera_shake"):
			tree.current_scene.call("trigger_camera_shake", event.direction, event.camera_shake_strength, 0.08)

	if area.has_method("receive_hit"): area.call("receive_hit", event)
	elif area.get_parent() and area.get_parent().has_method("receive_hit"): area.get_parent().call("receive_hit", event)
