class_name TestDummyTarget
extends CharacterBody2D

enum DummyType {
	STATIONARY,
	BLOCKING,
	DAMAGE,
	KNOCKBACK,
}

@export var dummy_type: DummyType = DummyType.STATIONARY
@export var max_health := 100.0
@export var max_stability := 60.0
@export var friction := 450.0

var health := 100.0
var stability := 60.0
var hit_count := 0
var total_damage_received := 0.0
var last_damage := 0.0
var flash := 0.0
var local_time_scale := 1.0

var react_offset := Vector2.ZERO
var react_tilt := 0.0
var react_time := 0.0
var react_duration := 0.0
var react_type := ""
var is_blocking := false

var hurtbox: Area2D

func _ready() -> void:
	health = max_health
	stability = max_stability
	if dummy_type == DummyType.BLOCKING:
		is_blocking = true
	
	if not has_node("Hurtbox"):
		var area := Area2D.new()
		area.name = "Hurtbox"
		area.collision_layer = 4
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("owner_character", self)
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(24, 260)
		collider.shape = shape
		collider.position.y = 50
		area.add_child(collider)
		add_child(area)
		hurtbox = area
	else:
		hurtbox.set_meta("owner_character", self)

func receive_hit(hit_data: Variant) -> void:
	var dmg: float = hit_data.damage if (hit_data is Object and "damage" in hit_data) else float(hit_data)
	var poise_dmg: float = hit_data.poise_damage if (hit_data is Object and "poise_damage" in hit_data) else dmg * 1.5
	var impact_force: float = hit_data.impact_force if (hit_data is Object and "impact_force" in hit_data) else 60.0
	var direction: Vector2 = hit_data.direction if (hit_data is Object and "direction" in hit_data) else Vector2.RIGHT
	
	hit_count += 1
	flash = maxf(flash, 0.15)
	
	if dummy_type == DummyType.BLOCKING and stability > 0.0:
		dmg *= 0.25
		stability = maxf(0.0, stability - poise_dmg)
		if hit_data is Object and "is_blocked" in hit_data:
			hit_data.is_blocked = true
	else:
		stability = maxf(0.0, stability - poise_dmg)
	
	health = maxf(0.0, health - dmg)
	last_damage = dmg
	total_damage_received += dmg
	
	# Emit hit feedback
	if has_node("/root/HitstopManager") and hit_data is Object:
		hit_data.victim = self
		var manager = get_node("/root/HitstopManager")
		manager.request_hitstop(hit_data)
		
	var feedback = preload("res://scripts/realm_hit_feedback.gd")
	if feedback:
		feedback.emit_hit(self, dmg, Vector2(0, -63))
	
	# React motion / tilt
	react_duration = 0.20
	react_time = react_duration
	if dmg <= 8.0:
		react_type = "light"
		react_offset = direction * 2.0
		react_tilt = direction.x * 0.05
	elif dmg <= 15.0:
		react_type = "medium"
		react_offset = direction * 4.0
		react_tilt = direction.x * 0.09
	else:
		react_type = "heavy"
		react_offset = direction * 7.0
		react_tilt = direction.x * 0.15
	
	# Knockback impulse for kinematic dummy
	if dummy_type == DummyType.KNOCKBACK:
		velocity += direction * (impact_force * 1.6)

func _physics_process(delta: float) -> void:
	if local_time_scale <= 0.0:
		return
	delta *= local_time_scale
	flash = maxf(0.0, flash - delta)
	
	# Regenerate stability slowly
	if stability < max_stability:
		stability = minf(max_stability, stability + 15.0 * delta)
	
	if react_time > 0.0:
		react_time = maxf(0.0, react_time - delta)
		react_offset = react_offset.move_toward(Vector2.ZERO, 30.0 * delta)
		react_tilt = move_toward(react_tilt, 0.0, 0.8 * delta)
	else:
		react_offset = Vector2.ZERO
		react_tilt = 0.0
	
	if dummy_type == DummyType.KNOCKBACK:
		if absf(velocity.x) > 0.1:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		else:
			velocity.x = 0.0
		if not is_on_floor():
			velocity.y += 650.0 * delta
		move_and_slide()
	
	queue_redraw()

func set_local_time_scale(scale: float) -> void:
	local_time_scale = maxf(scale, 0.0)

func reset_state(initial_pos: Vector2) -> void:
	health = max_health
	stability = max_stability
	hit_count = 0
	total_damage_received = 0.0
	last_damage = 0.0
	flash = 0.0
	react_offset = Vector2.ZERO
	react_tilt = 0.0
	velocity = Vector2.ZERO
	global_position = initial_pos

func _draw() -> void:
	draw_set_transform(react_offset, react_tilt, Vector2.ONE)
	
	var base_col: Color
	match dummy_type:
		DummyType.STATIONARY:
			base_col = Color("707882")
		DummyType.BLOCKING:
			base_col = Color("4e9fa8")
		DummyType.DAMAGE:
			base_col = Color("8b6fb5")
		DummyType.KNOCKBACK:
			base_col = Color("c85050")
	
	var flash_w := clampf(flash / 0.10, 0.0, 1.0)
	var body_col := base_col.lerp(Color.WHITE, flash_w)
	
	# Stand pole
	draw_rect(Rect2(-3, -56, 6, 56), Color("2e3338"))
	# Base plate
	draw_rect(Rect2(-12, -4, 24, 4), Color("3d444c"))
	# Torso block
	draw_rect(Rect2(-10, -50, 20, 32), body_col)
	# Accent stripes
	draw_rect(Rect2(-8, -46, 16, 2), Color("1a1f24"))
	draw_rect(Rect2(-8, -28, 16, 2), Color("1a1f24"))
	# Head
	draw_circle(Vector2(0, -58), 6.0, body_col)
	# Bullseye
	draw_circle(Vector2(0, -36), 3.5, Color("1a1f24"))
	draw_circle(Vector2(0, -36), 1.5, Color.WHITE)
	
	# Blocking dummy shield outline
	if dummy_type == DummyType.BLOCKING:
		var shield_col := Color("62c7d4") if stability > 0.0 else Color("808080")
		draw_line(Vector2(-14, -54), Vector2(-14, -18), shield_col, 2.0)
		draw_line(Vector2(-14, -54), Vector2(-8, -58), shield_col, 2.0)
		draw_line(Vector2(-14, -18), Vector2(-8, -14), shield_col, 2.0)
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# Damage & Status labels above dummy
	var font := ThemeDB.fallback_font
	if dummy_type == DummyType.DAMAGE or dummy_type == DummyType.BLOCKING:
		var hp_ratio := clampf(health / max_health, 0.0, 1.0)
		draw_rect(Rect2(-16, -72, 32, 4), Color("1a1f24"))
		draw_rect(Rect2(-16, -72, 32 * hp_ratio, 4), Color("8b6fb5"))
		var stab_ratio := clampf(stability / max_stability, 0.0, 1.0)
		draw_rect(Rect2(-16, -67, 32, 3), Color("1a1f24"))
		draw_rect(Rect2(-16, -67, 32 * stab_ratio, 3), Color("62c7d4"))
	
	# Hits label
	draw_string(font, Vector2(-18, -78), "HITS: %d" % hit_count, HORIZONTAL_ALIGNMENT_CENTER, 36, 8, Color("e4e7eb"))
