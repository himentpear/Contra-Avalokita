class_name WeaponData
extends Resource

@export var id: StringName = &"sword"
@export var display_name: String = "Sword"
@export var weapon_scene: PackedScene = preload("res://scenes/weapons/sword.tscn")
@export var weapon_class: String = "blade"
@export var attack_animations: PackedStringArray = PackedStringArray(["Blade/Attack_1", "Blade/Attack_2", "Blade/Attack_3"])
@export var attack_windows: Array[Vector2] = [Vector2(0.20, 0.28), Vector2(0.16, 0.25), Vector2(0.28, 0.44)]
@export var attack_damages: Array[float] = [10.0, 10.0, 10.0]
@export var combo_impacts: Array[float] = [0.50, 0.75, 1.30]
@export var combo_buffer_start: float = 0.15
@export var feedback_weapon_type: String = "slash"
@export var blade_projection: float = 1.0
@export var blade_depth: float = 0.0

static func create_default_sword() -> Resource:
	var script: GDScript = load("res://scripts/resources/weapon_data.gd")
	var data = script.new()
	data.id = &"sword"
	data.display_name = "Sword"
	data.weapon_scene = preload("res://scenes/weapons/sword.tscn")
	data.weapon_class = "blade"
	return data
