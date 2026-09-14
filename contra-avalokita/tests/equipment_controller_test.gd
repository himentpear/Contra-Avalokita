extends SceneTree

var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		errors += 1
		push_error("FAIL: " + message)

func run() -> void:
	var arena := load("res://scenes/test_arena.tscn").instantiate() as Node2D
	root.add_child(arena)
	var p: MudCharacter = arena.player
	p.player_controlled = false
	for i in 5:
		await physics_frame

	# 1. Verify EquipmentController on MudCharacter
	check(p.equipment_controller != null, "EquipmentController is mounted on MudCharacter")
	check(p.weapons != null, "MudCharacter.weapons facade is available")
	check(p.is_armed(), "Character begins armed with default weapon")

	# 2. Unequip weapon
	p.weapons.equip(null)
	check(not p.is_armed(), "Equipping null unarms the character")
	check(p.weapons.current == null, "weapons.current is null when unarmed")

	# 3. Equip with WeaponData Resource
	var WeaponDataScript = load("res://scripts/resources/weapon_data.gd")
	var custom_data = WeaponDataScript.new()
	custom_data.id = &"silver_blade"
	custom_data.display_name = "Silver Blade"
	custom_data.weapon_scene = preload("res://scenes/weapons/sword.tscn")
	var damages: Array[float] = [22.5, 30.0, 45.0]
	custom_data.attack_damages = damages
	var impacts: Array[float] = [1.1, 1.4, 2.0]
	custom_data.combo_impacts = impacts

	p.equipment_controller.equip(custom_data)
	check(p.is_armed(), "Equipping WeaponData successfully arms the character")
	check(p.weapons.current != null, "weapons.current is valid after equipping WeaponData")
	check(p.weapons.current.weapon_name == "Silver Blade", "Weapon name is set from WeaponData display_name")
	check(p.weapons.current.damage == 22.5, "Weapon base damage is set from WeaponData attack_damages")
	check(p.weapons.current_data == custom_data, "current_data matches equipped WeaponData")

	# 4. Equip with PackedScene (backward compatibility)
	p.weapons.equip(p.weapons.default_weapon)
	check(p.is_armed(), "Re-equipping PackedScene arms the character")
	check(p.weapons.current != null, "weapons.current is valid after PackedScene equip")

	# 5. Drop weapon to ground
	check(not p.weapons.weapon_dropped, "Weapon is initially not dropped")
	p.weapons.drop_weapon_to_ground()
	check(p.weapons.weapon_dropped, "Weapon drops to ground successfully")

	print("EQUIPMENT CONTROLLER RESULT: ", errors, " failures")
	quit(errors)
