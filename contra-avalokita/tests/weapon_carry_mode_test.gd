extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	root.add_child(actor)
	await process_frame
	actor.set_physics_process(false)
	var manager: WeaponManager = actor.weapons
	var sword: MudWeapon = manager.current

	check(manager.get_node_or_null("BackSlot") is Marker2D, "WeaponSlots owns an explicit BackSlot")
	check(manager.carry_mode == EquipmentController.CarryMode.BACK, "Equipped sword defaults to BACK mode")
	check(sword.get_parent() == manager.back_slot, "Default sword is parented to BackSlot")
	check(manager.back_slot.z_index < 0, "BackSlot renders behind the main body")
	actor._sync_visual(0.0)
	var back_grip := (sword.get_node("WeaponGrip") as Marker2D).global_position
	var back_tip := (sword.get_node("TrailOrigin") as Marker2D).global_position
	var back_axis := back_tip - back_grip
	check(manager.back_slot.position.x < -5.0, "Back sword grip stays tight to the rear edge of the torso")
	check(back_axis.x < -20.0 and back_axis.y < -20.0, "Back sword uses a clear 45 degree rear-up diagonal")
	check(is_equal_approx(back_axis.length(), 32.0), "Back sword keeps its full visible blade length")
	check(actor.get_state_animation(&"Idle") == &"Idle_Unarmed", "Back carry uses natural Idle arms")
	check(actor.get_state_animation(&"Walk") == &"Walk_Unarmed", "Back carry uses natural Walk arm swing")
	check(actor.get_state_animation(&"Run") == &"Run_Unarmed", "Back carry uses natural Run arm swing")

	actor.start_attack(0)
	actor._sync_visual(0.0)
	check(manager.carry_mode == EquipmentController.CarryMode.HAND and sword.get_parent() == manager.main_hand, "Attack draws sword into MainHandSlot")
	check(actor.attack_animation() == &"Blade/Attack_1", "Back carry preserves blade attack resolution")
	actor.attack_time = sword.attack_windows[0].x + 0.01
	actor._sync_visual(0.0)
	check(sword.active, "HAND mode updates the weapon attack window")

	actor.cancel_attack_pose()
	actor._sync_visual(0.0)
	await process_frame
	check(manager.carry_mode == EquipmentController.CarryMode.BACK and sword.get_parent() == manager.back_slot, "Attack recovery returns sword to BackSlot")
	check(not sword.active and not sword.hitbox.monitoring and sword.trail_points.is_empty(), "BACK mode disables hitbox, trail and attack state")
	sword.update_attack(sword.attack_windows[0].x + 0.01, true)
	check(not sword.active, "Weapon rejects direct attack updates while carried on back")

	actor.block_requested = true
	actor.combat_component.handle_block_input()
	actor._sync_visual(0.0)
	check(manager.carry_mode == EquipmentController.CarryMode.HAND, "Armed block draws sword")
	actor.block_requested = false
	actor.combat_component.handle_block_input()
	actor._sync_visual(0.0)
	check(manager.carry_mode == EquipmentController.CarryMode.BACK, "Leaving block sheathes sword")
	manager.set_action_requires_hand(true)
	check(manager.carry_mode == EquipmentController.CarryMode.HAND, "Future hand-required actions can request HAND mode through one interface")
	manager.set_action_requires_hand(false)

	actor.facing = 1.0
	actor._sync_visual(0.0)
	var forward_vector: Vector2 = (sword.get_node("TrailOrigin") as Marker2D).global_position - (sword.get_node("WeaponGrip") as Marker2D).global_position
	actor.facing = -1.0
	actor._sync_visual(0.0)
	var mirrored_vector: Vector2 = (sword.get_node("TrailOrigin") as Marker2D).global_position - (sword.get_node("WeaponGrip") as Marker2D).global_position
	check(absf(mirrored_vector.x + forward_vector.x) <= 0.01 and absf(mirrored_vector.y - forward_vector.y) <= 0.01, "Back sword mirrors cleanly with Visual facing")

	var weapon_visual_registered := false
	for item in actor.lighting_controller.binding.weapon_renderers:
		weapon_visual_registered = weapon_visual_registered or item == sword or sword.is_ancestor_of(item)
	check(weapon_visual_registered, "Lighting binding follows the weapon across both slots")

	actor.queue_free()
	await process_frame
	print("WEAPON CARRY MODE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
