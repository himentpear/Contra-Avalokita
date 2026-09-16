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
	print("--- Running Character Lighting Direction & Smoothing Test ---")
	LightingRegistryScript.clear()
	
	var arena = Node2D.new()
	arena.name = "TestArena"
	root.add_child(arena)
	
	# Create left warm light
	var left_light = PointLight2D.new()
	left_light.name = "LeftWarmLight"
	left_light.position = Vector2(-200.0, -100.0)
	left_light.color = Color(1.0, 0.7, 0.3, 1.0)
	left_light.energy = 1.2
	left_light.texture_scale = 8.0 # Large effective radius
	arena.add_child(left_light)
	LightingRegistryScript.register_light(left_light)
	
	# Create right cool light
	var right_light = PointLight2D.new()
	right_light.name = "RightCoolLight"
	right_light.position = Vector2(200.0, -100.0)
	right_light.color = Color(0.3, 0.6, 1.0, 1.0)
	right_light.energy = 1.2
	right_light.texture_scale = 8.0
	arena.add_child(right_light)
	LightingRegistryScript.register_light(right_light)
	
	# Create test character
	var char_node = Node2D.new()
	char_node.name = "CharNode"
	char_node.position = Vector2(-150.0, 0.0)
	arena.add_child(char_node)
	
	var body_sprite = Sprite2D.new()
	body_sprite.name = "Body"
	char_node.add_child(body_sprite)
	
	var controller = CharacterLightingControllerScript.new()
	var profile = CharacterLightingProfileScript.new()
	profile.light_response_speed = 15.0
	var binding = CharacterLightingBindingScript.new()
	binding.bind_body(body_sprite)
	
	char_node.add_child(controller)
	controller.setup(profile, binding)
	
	# Step a few frames to settle on the left light
	for i in range(10):
		controller._process(0.05)
	
	check(controller.current_direction.x < 0.0, "Character at left side has direction pointing left toward warm light (got dir: %v)" % controller.current_direction)
	check(controller.current_energy > 0.1, "Character receives positive light energy (got: %f)" % controller.current_energy)
	check(controller.current_color.r > controller.current_color.b, "Character color is predominantly warm (R: %f, B: %f)" % [controller.current_color.r, controller.current_color.b])
	
	# Move character across center from X=-150 to X=+150
	var prev_dir = controller.current_direction
	var smooth_transition := true
	var steps := 25
	for step in range(steps):
		var t = float(step + 1) / float(steps)
		char_node.position.x = lerpf(-150.0, 150.0, t)
		controller._process(0.05)
		
		# Check for NaNs or zero length
		if is_nan(controller.current_direction.x) or is_nan(controller.current_direction.y):
			smooth_transition = false
			push_error("NaN encountered in current_direction")
			break
		
		if not controller.current_direction.is_normalized():
			smooth_transition = false
			push_error("current_direction is not normalized: %v" % controller.current_direction)
			break
			
		# Check angle difference between consecutive steps to ensure no popping
		var angle_diff = absf(prev_dir.angle_to(controller.current_direction))
		if angle_diff > PI * 0.5: # More than 90 deg sudden jump
			smooth_transition = false
			push_error("Abrupt jump in direction: angle diff = %f rad" % angle_diff)
			break
		prev_dir = controller.current_direction

	check(smooth_transition, "Direction transition across center is smooth with no flips or NaNs")
	
	# Now settle at right side
	for i in range(10):
		controller._process(0.05)
		
	check(controller.current_direction.x > 0.0, "Character at right side has direction pointing right toward cool light (got dir: %v)" % controller.current_direction)
	check(controller.current_color.b > controller.current_color.r, "Character color is predominantly cool (R: %f, B: %f)" % [controller.current_color.r, controller.current_color.b])
	
	# Test fallback direction when lights are turned off
	left_light.energy = 0.0
	right_light.energy = 0.0
	
	for i in range(20):
		controller._process(0.05)
		
	check(controller.current_energy < 0.05, "Energy smoothly decays to near zero when lights turn off (got %f)" % controller.current_energy)
	var fallback_target = Vector2(0.0, -1.0)
	var fallback_dot = controller.current_direction.dot(fallback_target)
	check(fallback_dot > 0.95, "Direction transitions to fallback direction (dot product: %f)" % fallback_dot)
	
	arena.queue_free()
	LightingRegistryScript.clear()
	
	if failures == 0:
		print("=== ALL CHARACTER LIGHTING DIRECTION TESTS PASSED ===")
		quit(0)
	else:
		push_error("=== %d TESTS FAILED ===" % failures)
		quit(1)
