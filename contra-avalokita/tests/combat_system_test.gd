extends SceneTree

const Faction = preload("res://scripts/entities/faction.gd")
const Damageable = preload("res://scripts/entities/damageable.gd")
const CombatSystem = preload("res://scripts/systems/combat_system.gd")
const DamageSystem = preload("res://scripts/systems/damage_system.gd")
const HitstopSystem = preload("res://scripts/systems/hitstop_system.gd")
const HitEvent = preload("res://scripts/hit_event.gd")

var _failures: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		printerr("FAIL: ", message)

func _init() -> void:
	print("--- Running Combat Domain System Tests ---")
	test_faction()
	test_damage_system()
	test_hitstop_system()
	test_combat_system()
	test_damageable_entity()
	
	if _failures == 0:
		print("COMBAT SYSTEM RESULT: 0 failures")
	else:
		printerr("COMBAT SYSTEM RESULT: ", _failures, " failures")
	quit(_failures)

func test_faction() -> void:
	check(Faction.is_hostile(Faction.Type.PLAYER, Faction.Type.ENEMY), "Player is hostile to Enemy")
	check(not Faction.is_hostile(Faction.Type.PLAYER, Faction.Type.PLAYER), "Player is not hostile to Player")
	check(not Faction.is_hostile(Faction.Type.ENEMY, Faction.Type.ENEMY), "Enemy is not hostile to Enemy")
	check(not Faction.is_hostile(Faction.Type.NEUTRAL, Faction.Type.PLAYER), "Neutral is not hostile to Player")
	check(not Faction.is_hostile(Faction.Type.PLAYER, Faction.Type.NEUTRAL), "Player is not hostile to Neutral")
	check(Faction.is_hostile(Faction.Type.ENVIRONMENT, Faction.Type.PLAYER), "Environment is hostile to Player")
	check(Faction.is_hostile(Faction.Type.ENVIRONMENT, Faction.Type.ENEMY), "Environment is hostile to Enemy")
	
	var node := Node.new()
	node.name = "TestDummy"
	check(Faction.get_faction_of(node) == Faction.Type.ENEMY, "Dummy name prefix maps to ENEMY faction")
	
	node.set_meta("faction", Faction.Type.PLAYER)
	check(Faction.get_faction_of(node) == Faction.Type.PLAYER, "Metadata overrides faction")
	node.free()

func test_damage_system() -> void:
	var event_raw := DamageSystem.normalize_hit_event(25.0, Vector2.LEFT)
	check(event_raw is HitEvent, "normalize_hit_event returns HitEvent")
	check(is_equal_approx(event_raw.damage, 25.0), "Normalized damage matches float input")
	check(event_raw.direction == Vector2.LEFT, "Normalized direction matches fallback")
	
	var existing_event := HitEvent.new()
	existing_event.damage = 42.0
	var pass_through := DamageSystem.normalize_hit_event(existing_event)
	check(pass_through == existing_event, "normalize_hit_event passes through existing HitEvent")
	
	# Block check
	var mock_victim := Node.new()
	var block_event := HitEvent.new()
	block_event.damage = 100.0
	block_event.poise_damage = 50.0
	var unblocked := DamageSystem.calculate_block(block_event, mock_victim, true)
	check(not unblocked["is_blocked"], "Non-blocking victim reports is_blocked == false")
	check(is_equal_approx(unblocked["damage"], 100.0), "Unblocked damage is 100%")
	mock_victim.free()
	
	# Critical hit
	var crit_event := HitEvent.new()
	crit_event.hit_region = &"HEAD"
	check(DamageSystem.calculate_critical(crit_event, null), "HEAD hit region triggers critical")
	check(crit_event.is_critical, "crit_event marked is_critical == true")
	
	var body_event := HitEvent.new()
	body_event.hit_region = &"UPPER_TORSO"
	var stunned_victim := Node.new()
	stunned_victim.set_meta("reaction_state", &"HeavyHit")
	check(DamageSystem.calculate_critical(body_event, stunned_victim), "HeavyHit victim triggers critical on body hit")
	stunned_victim.free()
	
	# Poise break
	check(DamageSystem.evaluate_poise_break(10.0, 10.0), "Stability reaching 0.0 triggers poise break")
	check(DamageSystem.evaluate_poise_break(10.0, 15.0), "Stability below 0.0 triggers poise break")
	check(not DamageSystem.evaluate_poise_break(10.0, 5.0), "Stability above 0.0 does not trigger poise break")

func test_hitstop_system() -> void:
	var hit := HitEvent.new()
	hit.impact = 1.0
	var flash := HitstopSystem.calculate_hit_flash(hit)
	check(flash.has("intensity") and flash.has("duration"), "calculate_hit_flash returns intensity and duration")
	check(flash["intensity"] > 0.5, "Flash intensity is positive and significant")
	
	hit.is_blocked = true
	var blocked_flash := HitstopSystem.calculate_hit_flash(hit)
	check(blocked_flash["intensity"] < flash["intensity"], "Blocked hit reduces flash intensity")
	
	hit.is_critical = true
	var crit_flash := HitstopSystem.calculate_hit_flash(hit)
	check(is_equal_approx(crit_flash["intensity"], 0.95), "Critical hit grants maximum flash intensity")

func test_combat_system() -> void:
	var event := HitEvent.new()
	event.direction = Vector2(1.0, 0.0)
	event.impact_force = 100.0
	
	var ground_kb := CombatSystem.calculate_knockback(event, false)
	var air_kb := CombatSystem.calculate_knockback(event, true)
	check(is_equal_approx(ground_kb.x, 100.0), "Ground knockback equals impact force")
	check(is_equal_approx(air_kb.x, 125.0), "Air knockback scales by 1.25x")
	
	# Combo
	var combo_res := CombatSystem.evaluate_combo(0, 3, true)
	check(combo_res["continue_combo"], "Queued combo continues to stage 1")
	check(combo_res["next_stage"] == 1, "Next stage is 1")
	
	var combo_end := CombatSystem.evaluate_combo(2, 3, true)
	check(not combo_end["continue_combo"], "Max combo does not continue")
	check(combo_end["next_stage"] == 0, "Combo resets to 0")
	
	var unbuffered := CombatSystem.evaluate_combo(0, 3, false)
	check(not unbuffered["continue_combo"], "Unbuffered attack does not advance combo")
	
	# Reaction tier resolve
	var light_event := HitEvent.new()
	light_event.hit_type = &"LightHit"
	light_event.direction = Vector2.RIGHT
	light_event.target_push_distance = 2.5
	var r_light := CombatSystem.resolve_reaction(light_event, null, false, false)
	check(r_light["tier"] == &"LightHit", "Light hit resolves to LightHit tier")
	check(r_light["push_offset"] == Vector2(2.5, 0.0), "Target push offset resolves correctly")
	
	var broken_light := CombatSystem.resolve_reaction(light_event, null, false, true)
	check(broken_light["tier"] == &"HeavyHit", "Poise break upgrades reaction to HeavyHit")
	
	var air_reaction := CombatSystem.resolve_reaction(light_event, null, true, false)
	check(air_reaction["tier"] == &"AirHit", "Airborne victim receives AirHit tier")

func test_damageable_entity() -> void:
	var damageable := Damageable.new()
	var attacker := Node.new()
	attacker.name = "Player"
	attacker.set_meta("faction", Faction.Type.PLAYER)
	
	damageable.faction_type = Faction.Type.ENEMY
	check(damageable.can_be_damaged_by(attacker), "Enemy Damageable can be damaged by Player")
	
	damageable.invulnerable = true
	check(not damageable.can_be_damaged_by(attacker), "Invulnerable Damageable cannot be damaged")
	
	damageable.invulnerable = false
	damageable.faction_type = Faction.Type.PLAYER
	check(not damageable.can_be_damaged_by(attacker), "Same faction cannot damage each other")
	
	damageable.free()
	attacker.free()
