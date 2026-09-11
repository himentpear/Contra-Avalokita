class_name MudWeapon
extends Node2D
signal struck(target: Area2D, damage: float)
@export var weapon_name := "Sword"
@export var damage := 10.0
@export var grip_scale := 1.0
@export var stretch_multiplier := 1.0
@export var active_start := 0.22
@export var active_end := 0.35
var hit_targets: Array[int] = []
var active := false
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	hitbox.area_entered.connect(_on_area_entered)
	hitbox.monitoring = false

func begin_attack() -> void:
	hit_targets.clear()

func update_attack(t: float, attacking: bool) -> void:
	active = attacking and t >= active_start and t <= active_end
	hitbox.set_deferred("monitoring", active)
	# Recheck overlaps so starting inside a hurtbox still produces one hit.
	if active and hitbox.monitoring:
		for area in hitbox.get_overlapping_areas(): _on_area_entered(area)

func _on_area_entered(area: Area2D) -> void:
	if not active or area.get_meta("owner_character", null) == get_meta("owner_character", null): return
	var id := area.get_instance_id()
	if hit_targets.has(id): return
	hit_targets.append(id)
	struck.emit(area, damage)
	if area.has_method("receive_hit"): area.call("receive_hit", damage)
	elif area.get_parent().has_method("receive_hit"): area.get_parent().call("receive_hit", damage)
