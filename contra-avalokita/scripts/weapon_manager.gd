class_name WeaponManager
extends Node2D
@export var default_weapon: PackedScene = preload("res://scenes/weapons/sword.tscn")
var main_hand: Marker2D
var current: MudWeapon
var owner_character: Node

func _ready() -> void:
	main_hand = Marker2D.new()
	main_hand.name = "MainHandSlot"
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

func sync(rig: MudRig, attack_time: float, attacking: bool) -> void:
	main_hand.position = rig.point(&"ArmFrontEnd")
	main_hand.rotation = rig.weapon_angle
	main_hand.z_index = 6 if not attacking or attack_time > 0.18 else -2
	if current: current.update_attack(attack_time, attacking)

