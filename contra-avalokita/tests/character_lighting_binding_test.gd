extends SceneTree

const CharacterLightingProfileScript = preload("res://scripts/presentation/lighting/character_lighting_profile.gd")
const CharacterLightingBindingScript = preload("res://scripts/presentation/lighting/character_lighting_binding.gd")
const CharacterLightingControllerScript = preload("res://scripts/presentation/lighting/character_lighting_controller.gd")

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
	print("--- Running Character Lighting Binding Test ---")
	test_programmatic_binding()
	test_nodepath_resolution()
	test_dynamic_weapon_slot()
	test_mask_application()
	test_missing_node_graceful_handling()
	test_mud_character_binding()
	
	if failures == 0:
		print("=== ALL CHARACTER LIGHTING BINDING TESTS PASSED ===")
		quit(0)
	else:
		push_error("=== %d TESTS FAILED ===" % failures)
		quit(1)

func test_programmatic_binding() -> void:
	print("\n-- Testing programmatic binding --")
	var binding = CharacterLightingBindingScript.new()
	var body_sprite = Sprite2D.new()
	var weapon_sprite = Sprite2D.new()
	var eye_sprite = Sprite2D.new()
	var shadow_node = Node2D.new()
	
	binding.bind_body(body_sprite)
	binding.bind_weapon(weapon_sprite)
	binding.bind_emissive(eye_sprite)
	binding.bind_ground_shadow(shadow_node)
	
	check(binding.body_renderers.has(body_sprite), "bind_body registers body sprite")
	check(binding.weapon_renderers.has(weapon_sprite), "bind_weapon registers weapon sprite")
	check(binding.emissive_renderers.has(eye_sprite), "bind_emissive registers emissive sprite")
	check(binding.ground_shadow == shadow_node, "bind_ground_shadow registers ground shadow")
	
	binding.unbind_weapon(weapon_sprite)
	check(not binding.weapon_renderers.has(weapon_sprite), "unbind_weapon removes weapon sprite")
	
	binding.bind_weapon(weapon_sprite)
	binding.clear_weapons()
	check(binding.weapon_renderers.is_empty(), "clear_weapons clears weapon renderers")
	
	body_sprite.free()
	weapon_sprite.free()
	eye_sprite.free()
	shadow_node.free()

func test_nodepath_resolution() -> void:
	print("\n-- Testing NodePath resolution --")
	var root_node = Node2D.new()
	var visual = Node2D.new()
	visual.name = "Visual"
	root_node.add_child(visual)
	
	var body = Sprite2D.new()
	body.name = "Body"
	visual.add_child(body)
	
	var eyes = Sprite2D.new()
	eyes.name = "Eyes"
	visual.add_child(eyes)
	
	var binding = CharacterLightingBindingScript.new()
	var b_paths: Array[NodePath] = [NodePath("Visual/Body")]
	var e_paths: Array[NodePath] = [NodePath("Visual/Eyes")]
	binding.body_renderer_paths = b_paths
	binding.emissive_renderer_paths = e_paths
	
	binding.resolve(root_node)
	check(binding.body_renderers.size() == 1, "Resolved 1 body renderer via path")
	check(binding.body_renderers[0] == body, "Resolved body renderer is correct node")
	check(binding.emissive_renderers.size() == 1, "Resolved 1 emissive renderer via path")
	check(binding.emissive_renderers[0] == eyes, "Resolved emissive renderer is correct node")
	
	root_node.free()

func test_dynamic_weapon_slot() -> void:
	print("\n-- Testing dynamic weapon slot tracking --")
	var root_node = Node2D.new()
	root.add_child(root_node)
	
	var slot = Node2D.new()
	slot.name = "WeaponSlot"
	root_node.add_child(slot)
	
	var binding = CharacterLightingBindingScript.new()
	binding.weapon_slot_path = NodePath("WeaponSlot")
	binding.resolve(root_node)
	
	check(binding.weapon_renderers.is_empty(), "Initially no weapon renderers in slot")
	
	var sword = Sprite2D.new()
	sword.name = "Sword"
	slot.add_child(sword)
	
	check(binding.weapon_renderers.has(sword), "Weapon added to slot is dynamically registered")
	
	slot.remove_child(sword)
	check(not binding.weapon_renderers.has(sword), "Weapon removed from slot is dynamically unregistered")
	
	sword.free()
	root_node.queue_free()

func test_mask_application() -> void:
	print("\n-- Testing mask application via CharacterLightingController --")
	var root_node = Node2D.new()
	var body = Sprite2D.new()
	var eyes = Sprite2D.new()
	var weapon = Sprite2D.new()
	root_node.add_child(body)
	root_node.add_child(eyes)
	root_node.add_child(weapon)
	
	var controller = CharacterLightingControllerScript.new()
	var profile = CharacterLightingProfileScript.new()
	profile.actor_light_mask = 8
	profile.emissive_light_mask = 32
	
	var binding = CharacterLightingBindingScript.new()
	binding.bind_body(body)
	binding.bind_emissive(eyes)
	binding.bind_weapon(weapon)
	
	controller.setup(profile, binding)
	root_node.add_child(controller)
	
	check(body.light_mask == 8, "Body receives actor_light_mask (8)")
	check(weapon.light_mask == 8, "Weapon receives actor_light_mask (8)")
	check(eyes.light_mask == 32, "Emissive eye receives emissive_light_mask (32)")
	
	root_node.free()

func test_missing_node_graceful_handling() -> void:
	print("\n-- Testing graceful handling of missing node paths --")
	var root_node = Node2D.new()
	var binding = CharacterLightingBindingScript.new()
	var b_paths: Array[NodePath] = [NodePath("NonExistent/BodyPath")]
	var e_paths: Array[NodePath] = [NodePath("NonExistent/EyesPath")]
	binding.body_renderer_paths = b_paths
	binding.emissive_renderer_paths = e_paths
	binding.weapon_slot_path = NodePath("NonExistent/Slot")
	
	# Should not crash or throw unhandled errors
	binding.resolve(root_node)
	check(binding.body_renderers.is_empty(), "Missing body path safely results in empty renderers")
	check(binding.emissive_renderers.is_empty(), "Missing emissive path safely results in empty renderers")
	check(binding.weapon_renderers.is_empty(), "Missing weapon slot safely results in empty renderers")
	
	root_node.free()

func test_mud_character_binding() -> void:
	print("\n-- Testing Mud character scene binding --")
	var mud_scene: PackedScene = preload("res://scenes/mud_character.tscn")
	check(mud_scene != null, "mud_character.tscn preloads successfully")
	var mud = mud_scene.instantiate()
	check(mud != null, "mud_character.tscn instantiates successfully")
	root.add_child(mud)
	
	var controller = mud.get_node_or_null("Visual/CharacterLightingController") as CharacterLightingControllerScript
	check(controller != null, "Mud has CharacterLightingController under Visual")
	if controller:
		check(controller.binding != null, "Mud controller has binding resource")
		check(controller.profile != null, "Mud controller has profile resource")
		check(controller.binding.body_renderers.size() > 0, "Mud binding resolved body renderer(s) (count: %d)" % controller.binding.body_renderers.size())
		check(controller.binding.emissive_renderers.size() > 0, "Mud binding resolved emissive renderer(s) (count: %d)" % controller.binding.emissive_renderers.size())
		check(controller.binding.ground_shadow != null, "Mud binding resolved ground shadow")
		
		# Check masks on Mud's actual nodes
		for b in controller.binding.body_renderers:
			check(b.light_mask == 8, "Mud body renderer mask is 8 (got %d)" % b.light_mask)
		for e in controller.binding.emissive_renderers:
			check(e.light_mask == 32, "Mud emissive renderer mask is 32 (got %d)" % e.light_mask)
	
	mud.queue_free()
