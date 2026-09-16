extends SceneTree

const CharacterLightingProfileScript = preload("res://scripts/presentation/lighting/character_lighting_profile.gd")
const CharacterLightingBindingScript = preload("res://scripts/presentation/lighting/character_lighting_binding.gd")
const CharacterLightingControllerScript = preload("res://scripts/presentation/lighting/character_lighting_controller.gd")
const LightingRegistryScript = preload("res://scripts/presentation/lighting/lighting_registry.gd")

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
	print("--- Running Second Character Proof Test (TestCharacterB) ---")
	LightingRegistryScript.clear()
	
	var arena = Node2D.new()
	arena.name = "SecondCharacterArena"
	root.add_child(arena)
	
	# Add point light to illuminate the second character
	var light = PointLight2D.new()
	light.position = Vector2(100.0, -150.0)
	light.color = Color(0.8, 0.9, 1.0, 1.0)
	light.energy = 1.5
	light.texture_scale = 6.0
	arena.add_child(light)
	LightingRegistryScript.register_light(light)
	
	# Construct TestCharacterB entirely in memory with stylized and emissive shaders
	var char_b = CharacterBody2D.new()
	char_b.name = "TestCharacterB"
	char_b.position = Vector2(0.0, 0.0)
	arena.add_child(char_b)
	
	var visual_root = Node2D.new()
	visual_root.name = "Visual"
	char_b.add_child(visual_root)
	
	var stylized_shader = load("res://shaders/character/stylized_character.gdshader")
	check(stylized_shader != null, "stylized_character.gdshader loads successfully")
	
	var emissive_shader = load("res://shaders/character/emissive_character.gdshader")
	check(emissive_shader != null, "emissive_character.gdshader loads successfully")
	
	# Body with stylized shader
	var body_mat = ShaderMaterial.new()
	body_mat.shader = stylized_shader
	var body_sprite = Sprite2D.new()
	body_sprite.name = "BodySprite"
	body_sprite.material = body_mat
	visual_root.add_child(body_sprite)
	
	# Weapon with stylized shader (high highlight)
	var weapon_mat = ShaderMaterial.new()
	weapon_mat.shader = stylized_shader
	var weapon_sprite = Sprite2D.new()
	weapon_sprite.name = "WeaponSprite"
	weapon_sprite.material = weapon_mat
	visual_root.add_child(weapon_sprite)
	
	# Eye with emissive shader
	var eye_mat = ShaderMaterial.new()
	eye_mat.shader = emissive_shader
	var eye_sprite = Sprite2D.new()
	eye_sprite.name = "EyeSprite"
	eye_sprite.material = eye_mat
	visual_root.add_child(eye_sprite)
	
	# Ground shadow
	var shadow_scene: PackedScene = preload("res://scenes/presentation/ground_shadow.tscn")
	check(shadow_scene != null, "ground_shadow.tscn preloads successfully")
	var ground_shadow = shadow_scene.instantiate() as Node2D
	visual_root.add_child(ground_shadow)
	
	# Dedicated profile for TestCharacterB
	var profile_b = CharacterLightingProfileScript.new()
	profile_b.minimum_ambient = 0.62
	profile_b.rim_strength = 0.55
	profile_b.weapon_highlight_strength = 1.85
	profile_b.light_response_speed = 20.0
	profile_b.actor_light_mask = 8
	profile_b.emissive_light_mask = 32
	profile_b.ground_shadow_enabled = true
	
	# Dedicated binding for TestCharacterB
	var binding_b = CharacterLightingBindingScript.new()
	binding_b.bind_body(body_sprite)
	binding_b.bind_weapon(weapon_sprite)
	binding_b.bind_emissive(eye_sprite)
	binding_b.bind_ground_shadow(ground_shadow)
	
	# Attach generic lighting controller
	var controller = CharacterLightingControllerScript.new()
	controller.setup(profile_b, binding_b)
	visual_root.add_child(controller)
	
	# Run simulation
	for i in range(15):
		controller._process(0.05)
	
	# 1. Verify light masks
	check(body_sprite.light_mask == 8, "TestCharacterB body light mask is 8")
	check(weapon_sprite.light_mask == 8, "TestCharacterB weapon light mask is 8")
	check(eye_sprite.light_mask == 32, "TestCharacterB emissive eye light mask is 32")
	
	# 2. Verify controller state
	check(controller.current_energy > 0.1, "TestCharacterB receives light energy (got: %f)" % controller.current_energy)
	check(controller.current_direction.x > 0.0, "TestCharacterB direction points toward right light (got: %v)" % controller.current_direction)
	
	# 3. Verify shader parameters injected into body material
	var body_min_amb = body_mat.get_shader_parameter("minimum_ambient")
	check(body_min_amb == 0.62, "TestCharacterB body material received custom minimum_ambient (0.62, got: %s)" % str(body_min_amb))
	var body_rim_str = body_mat.get_shader_parameter("rim_strength")
	check(body_rim_str == 0.55, "TestCharacterB body material received custom rim_strength (0.55, got: %s)" % str(body_rim_str))
	var body_light_dir = body_mat.get_shader_parameter("light_direction")
	check(body_light_dir is Vector2 and (body_light_dir as Vector2).x > 0.0, "TestCharacterB body material received dynamic light_direction (%s)" % str(body_light_dir))
	
	# 4. Verify shader parameters injected into weapon material
	var wpn_highlight = weapon_mat.get_shader_parameter("weapon_highlight_strength")
	check(wpn_highlight == 1.85, "TestCharacterB weapon material received custom weapon_highlight_strength (1.85, got: %s)" % str(wpn_highlight))
	
	# 5. Verify ground shadow state
	check(ground_shadow.visible == true, "TestCharacterB ground shadow is visible")
	check(ground_shadow.scale.x > 0.0, "TestCharacterB ground shadow has positive scale (%v)" % ground_shadow.scale)
	
	arena.queue_free()
	LightingRegistryScript.clear()
	
	if failures == 0:
		print("=== ALL SECOND CHARACTER PROOF TESTS PASSED ===")
		quit(0)
	else:
		push_error("=== %d TESTS FAILED ===" % failures)
		quit(1)
