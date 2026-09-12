extends SceneTree

var errors := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		errors += 1
		printerr("FAIL: ", message)
	else:
		print("PASS: ", message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena := preload("res://scripts/test_arena.gd").new()
	root.add_child(arena)
	await ticks(5)
	
	var p: MudCharacter = arena.player
	p.player_controlled = false
	var dummy = arena.dummy

	# 1. Test Input & Block Query
	check(not p.is_blocking(), "Player initially not blocking")
	check(p.action_state == &"None", "Initial action state is None")
	p.set_intent(0.0, false, false, true)
	await ticks(3)
	check(p.is_blocking(), "Player registers is_blocking == true on block intent")
	check(p.action_state == &"Block", "Action state is Block when blocking")

	# Release block
	p.set_intent(0.0, false, false, false)
	await ticks(4)
	check(not p.is_blocking(), "Player releases block cleanly")
	check(p.action_state == &"None", "Action state reverts to None")

	# 2. Test Armed Vertical Sword Guard & Horse Stance (剑倾斜7°前挺，下盘扎马步)
	check(p.is_armed(), "Player is equipped with sword")
	p.set_intent(0.0, false, false, true)
	await ticks(5)
	check(p.pose_composer.block_weight > 0.8, "Armed block pose blended in: weight=%.2f" % p.pose_composer.block_weight)
	var expected_sword_rot: float = -PI * 0.5 + deg_to_rad(7.0)
	check(absf(p.weapons.main_hand.rotation - expected_sword_rot) < 0.05, "Sword tilted ~7 deg toward enemy: rot=%.3f rad (expected %.3f)" % [p.weapons.main_hand.rotation, expected_sword_rot])
	check(p.weapons.main_hand.position.y < -18.0, "Sword grip positioned at chest height: y=%.1f" % p.weapons.main_hand.position.y)
	check(p.weapons.main_hand.z_index == 8, "Sword rendered in front of chest: z_index=%d" % p.weapons.main_hand.z_index)

	# Test Horse Stance & Braced Posture (后脚撑地, 髋下沉, 前膝微屈, 胸略后仰)
	var pelvis_y: float = (p.skeleton.get_node("Pelvis") as Bone2D).position.y
	check(pelvis_y > -31.5 and pelvis_y < -29.5, "Pelvis lowered 4-6px: y=%.1f" % pelvis_y)
	var torso_rot: float = (p.skeleton.get_node("Pelvis/Torso") as Bone2D).rotation
	check(absf(torso_rot - deg_to_rad(-3.0)) < 0.03, "Torso pitched backward 2-4 deg: rot=%.3f rad" % torso_rot)
	var tf_rot := p._thigh_front_bone.rotation
	var tb_rot := p._thigh_back_bone.rotation
	var sf_rot := p._shin_front_bone.rotation
	var sb_rot := p._shin_back_bone.rotation
	check(tf_rot < -0.30, "Front thigh angled forward into stance: rot=%.2f rad" % tf_rot)
	check(tb_rot > 0.05, "Back thigh braced backward: rot=%.2f rad" % tb_rot)
	check(sf_rot > 0.35 and sb_rot > 0.25, "Knees flexed: sf=%.2f, sb=%.2f" % [sf_rot, sb_rot])
	var ff_x := p._foot_front_bone.global_position.x - p.global_position.x
	var fb_x := p._foot_back_bone.global_position.x - p.global_position.x
	check((ff_x - fb_x) > 15.0, "Feet spread wide: stance_width=%.1f px (> 15.0)" % (ff_x - fb_x))

	# 3. Test Armed Damage Mitigation & guard_hit Shockwave
	var hp_before := p.health
	var stab_before := p.stability
	var frontal_hit := HitEvent.new(20.0, Vector2.LEFT, p.global_position + Vector2(10, -25), 90.0, 30.0, &"MediumHit", &"blade")
	p.receive_hit(frontal_hit)
	var dmg_taken := hp_before - p.health
	check(absf(dmg_taken - 3.0) < 0.1, "Sword block absorbs 85%% damage: took %.1f / 20.0 (expected 3.0)" % dmg_taken)
	var stab_lost := stab_before - p.stability
	check(absf(stab_lost - 9.0) < 0.1, "Sword block absorbs 70%% poise damage: lost %.1f / 30.0 (expected 9.0)" % stab_lost)
	check(p.reaction_state == &"BlockHit", "Reaction state is BlockHit on successful block")
	check(p.reaction_push_offset == Vector2.ZERO, "Feet anchored: reaction_push_offset is strictly ZERO (no whole-body floor slip)")
	
	# Sample arm shockwave on frame 1
	await ticks(3)
	check(p.weapons.main_hand.rotation < expected_sword_rot - 0.03, "Sword deflects backward under impact: rot=%.3f < %.3f" % [p.weapons.main_hand.rotation, expected_sword_rot - 0.03])
	# Sample torso shockwave on frame 2-3
	await ticks(2)
	var torso_recoil_rot: float = (p.skeleton.get_node("Pelvis/Torso") as Bone2D).rotation
	check(torso_recoil_rot < torso_rot - 0.015, "Torso pitched further backward from impact wave: rot=%.3f < %.3f" % [torso_recoil_rot, torso_rot - 0.015])
	check(p.is_blocking(), "Player remains in guard after blocking")
	await ticks(6)

	# 4. Test Rear Hit Bypass (Backstab cannot be blocked from front)
	hp_before = p.health
	p.set_intent(0.0, false, false, true)
	await ticks(3)
	var rear_hit := HitEvent.new(10.0, Vector2.RIGHT, p.global_position + Vector2(-10, -25), 50.0, 15.0, &"LightHit", &"blade")
	p.receive_hit(rear_hit)
	var rear_dmg := hp_before - p.health
	check(absf(rear_dmg - 10.0) < 0.1, "Rear hit bypasses frontal guard: took %.1f / 10.0 full damage" % rear_dmg)
	await ticks(10)

	# 5. Test Unarmed High Head Guard (缩住 / Helmet Shell)
	p.weapons.equip(null)
	p.sync_weapon_animation()
	check(not p.is_armed(), "Player is unarmed")
	p.set_intent(0.0, false, false, true)
	await ticks(5)
	check(p.pose_composer.block_weight > 0.8, "Unarmed block pose blended in")
	var hand_f_y: float = p._hand_front_bone.global_position.y - p.global_position.y
	var hand_b_y: float = p._hand_back_bone.global_position.y - p.global_position.y
	check(hand_f_y < -30.0, "Lead arm raised to head/brow height: dy=%.1f" % hand_f_y)
	check(hand_b_y < -30.0, "Rear arm raised to head/temple height: dy=%.1f" % hand_b_y)
	var unarm_pelvis_y: float = (p.skeleton.get_node("Pelvis") as Bone2D).position.y
	check(unarm_pelvis_y > -29.5, "Unarmed block adopts deeper crouch (6-8px): y=%.1f" % unarm_pelvis_y)
	var unarm_torso_rot: float = (p.skeleton.get_node("Pelvis/Torso") as Bone2D).rotation
	check(unarm_torso_rot > deg_to_rad(3.5), "Unarmed torso pitched forward into shell: rot=%.3f rad" % unarm_torso_rot)
	var head_rot: float = (p.skeleton.get_node("Pelvis/Torso/Head") as Bone2D).rotation
	check(head_rot < -0.10, "Chin tucked down into chest: rot=%.3f rad" % head_rot)

	# 6. Test Unarmed Damage Mitigation (65% damage blocked)
	hp_before = p.health
	var frontal_punch := HitEvent.new(20.0, Vector2.LEFT, p.global_position + Vector2(10, -32), 80.0, 20.0, &"MediumHit", &"unarmed", &"HEAD")
	p.receive_hit(frontal_punch)
	var unarm_dmg := hp_before - p.health
	check(absf(unarm_dmg - 7.0) < 0.1, "Unarmed head guard absorbs 65%% damage: took %.1f / 20.0 (expected 7.0)" % unarm_dmg)
	check(p.reaction_state == &"BlockHit", "Reaction state is BlockHit on unarmed block")
	check(p.reaction_push_offset == Vector2.ZERO, "Unarmed feet anchored on block")
	await ticks(8)

	# 7. Test Guard Break (Poise depleted forces HeavyHit stagger)
	p.stability = 15.0
	p.set_intent(0.0, false, false, true)
	await ticks(2)
	var heavy_strike := HitEvent.new(30.0, Vector2.LEFT, p.global_position + Vector2(10, -32), 150.0, 60.0, &"HeavyHit", &"blade")
	p.receive_hit(heavy_strike)
	check(p.reaction_state == &"HeavyHit", "Depleting poise while blocking triggers Guard Break (HeavyHit stagger)")
	check(not p.is_blocking(), "Guard broken disables is_blocking")
	await ticks(25)

	# 8. Test Locomotion Guard Walk (Slowed speed without breaking guard or gait)
	p.stability = p.max_stability
	p.set_intent(1.0, false, false, true) # Move forward while holding block
	await ticks(10)
	check(p.is_blocking(), "Player remains in block while moving")
	check(p.velocity.x > 10.0, "Player moves while blocking (Guard Walk): vx=%.1f" % p.velocity.x)
	check(p.velocity.x < p.move_speed * 0.60, "Guard walk speed is moderated by multiplier: vx=%.1f < %.1f" % [p.velocity.x, p.move_speed * 0.60])
	
	# Test Facing Lock during retreat
	var prev_facing := p.facing
	p.set_intent(-1.0, false, false, true) # Backstep while blocking
	await ticks(6)
	check(p.facing == prev_facing, "Facing direction locked during block (does not flip when retreating)")

	# 9. Test InputMap Key L trigger
	p.player_controlled = true
	Input.action_press("block")
	await ticks(3)
	check(p.is_blocking(), "InputMap 'block' action triggers is_blocking == true on player_controlled character")
	Input.action_release("block")
	await ticks(3)
	check(not p.is_blocking(), "InputMap 'block' action release exits guard")

	# Cleanup
	arena.queue_free()
	await process_frame
	print("BLOCK RESULT: ", errors, " failures")
	quit(1 if errors else 0)
