extends SceneTree

const CharacterLightingProfileScript = preload("res://scripts/presentation/lighting/character_lighting_profile.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	print("--- Running Character Lighting Profile Test ---")
	test_default_values()
	test_custom_values()
	test_mud_profile()
	
	if failures == 0:
		print("=== ALL CHARACTER LIGHTING PROFILE TESTS PASSED ===")
		quit(0)
	else:
		push_error("=== %d TESTS FAILED ===" % failures)
		quit(1)

func test_default_values() -> void:
	print("\n-- Testing default profile values --")
	var profile = CharacterLightingProfileScript.new()
	check(profile != null, "Profile instantiates successfully")
	
	check(profile.actor_light_mask == 8, "Default actor_light_mask is 8 (ACTOR layer)")
	check(profile.emissive_light_mask == 32, "Default emissive_light_mask is 32 (EMISSIVE layer)")
	check(profile.minimum_ambient >= 0.55, "Default minimum_ambient is at least 0.55 to prevent CanvasModulate crush (got %f)" % profile.minimum_ambient)
	check(profile.light_response_speed > 0.0, "Default light_response_speed is positive (got %f)" % profile.light_response_speed)
	check(profile.rim_strength >= 0.0, "Default rim_strength is non-negative (got %f)" % profile.rim_strength)
	check(profile.weapon_highlight_strength >= 0.0, "Default weapon_highlight_strength is non-negative (got %f)" % profile.weapon_highlight_strength)
	check(profile.ground_shadow_enabled == false, "Default ground_shadow_enabled is false (disabled)")
	check(profile.ground_shadow_base_scale.x > 0.0, "Default ground_shadow_base_scale.x is positive")
	check(profile.ground_shadow_max_distance > 0.0, "Default ground_shadow_max_distance is positive")

func test_custom_values() -> void:
	print("\n-- Testing custom profile values --")
	var profile = CharacterLightingProfileScript.new()
	profile.minimum_ambient = 0.65
	profile.light_response_speed = 15.0
	profile.rim_strength = 0.75
	profile.weapon_highlight_strength = 1.8
	
	check(profile.minimum_ambient == 0.65, "Custom minimum_ambient sets correctly")
	check(profile.light_response_speed == 15.0, "Custom light_response_speed sets correctly")
	check(profile.rim_strength == 0.75, "Custom rim_strength sets correctly")
	check(profile.weapon_highlight_strength == 1.8, "Custom weapon_highlight_strength sets correctly")

func test_mud_profile() -> void:
	print("\n-- Testing Mud lighting profile asset --")
	var mud_profile = load("res://characters/mud/lighting/mud_lighting_profile.tres")
	check(mud_profile != null, "Mud profile resource loads successfully")
	check(mud_profile.actor_light_mask == 8, "Mud profile actor_light_mask is 8")
	check(mud_profile.emissive_light_mask == 32, "Mud profile emissive_light_mask is 32")
	check(mud_profile.minimum_ambient >= 0.55, "Mud profile minimum_ambient >= 0.55 (got %f)" % mud_profile.minimum_ambient)
	check(mud_profile.weapon_highlight_strength >= 1.0, "Mud profile weapon_highlight_strength >= 1.0 (got %f)" % mud_profile.weapon_highlight_strength)
