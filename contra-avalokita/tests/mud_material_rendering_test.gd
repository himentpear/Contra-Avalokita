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
	var scene := preload("res://scenes/mud_character.tscn")
	var actor_a := scene.instantiate() as MudCharacter
	var actor_b := scene.instantiate() as MudCharacter
	actor_a.player_controlled = false
	actor_b.player_controlled = false
	root.add_child(actor_a)
	root.add_child(actor_b)
	await process_frame
	actor_a.set_physics_process(false)
	actor_b.set_physics_process(false)

	var a := actor_a.body_renderer
	var b := actor_b.body_renderer
	a.macro_breakup_strength = 0.21
	a.medium_breakup_strength = 0.075
	a.grain_strength = 0.031
	a.cavity_strength = 0.18
	a.wetness = 0.23
	a.wet_threshold = 0.88
	a.wet_highlight_strength = 0.11
	a.rim_breakup_strength = 0.74
	a.arm_edge_width = 1.75
	b.macro_breakup_strength = 0.04
	a.sync_skeleton(actor_a.skeleton)
	b.sync_skeleton(actor_b.skeleton)

	var expected := {
		"macro_breakup_strength": 0.21,
		"medium_breakup_strength": 0.075,
		"grain_strength": 0.031,
		"cavity_strength": 0.18,
		"wetness": 0.23,
		"wet_threshold": 0.88,
		"wet_highlight_strength": 0.11,
		"rim_breakup_strength": 0.74,
		"arm_edge_width": 1.75,
	}
	for uniform_name: String in expected:
		var primary := float(a.shader_material.get_shader_parameter(uniform_name))
		check(is_equal_approx(primary, expected[uniform_name]), "Primary material receives %s" % uniform_name)
		for material in a.depth_materials:
			check(is_equal_approx(float(material.get_shader_parameter(uniform_name)), expected[uniform_name]), "Depth material receives %s" % uniform_name)

	check(a.shader_material != b.shader_material, "MudCharacter instances own separate primary material state")
	check(a.depth_materials[0] != b.depth_materials[0], "MudCharacter instances own separate depth material state")
	check(not is_equal_approx(float(a.shader_material.get_shader_parameter("macro_breakup_strength")), float(b.shader_material.get_shader_parameter("macro_breakup_strength"))), "Per-character mud tuning does not leak")
	var uploaded_arm_flags := a.shader_material.get_shader_parameter("arm_flags") as PackedFloat32Array
	check(uploaded_arm_flags.size() >= 27 and is_equal_approx(uploaded_arm_flags[6], 1.0) and is_equal_approx(uploaded_arm_flags[22], 1.0), "Back and front arm capsules are marked for stronger outlines")
	check(is_equal_approx(uploaded_arm_flags[0], 0.0) and is_equal_approx(uploaded_arm_flags[11], 0.0), "Leg and torso capsules retain the normal outline")

	a.set_hit_flash(0.65, Color.WHITE)
	check(is_equal_approx(float(a.shader_material.get_shader_parameter("hit_flash_amount")), 0.65), "Hit flash still overrides the body pipeline")
	for material in a.depth_materials:
		check(is_equal_approx(float(material.get_shader_parameter("hit_flash_amount")), 0.65), "Hit flash reaches every depth material")

	a.death_dissolve = 0.42
	a.sync_skeleton(actor_a.skeleton)
	check(is_equal_approx(float(a.shader_material.get_shader_parameter("death_dissolve")), 0.42), "Death dissolve remains connected")

	var controller = actor_a.lighting_controller
	controller.current_direction = Vector2(0.8, -0.2).normalized()
	controller.current_color = Color(1.0, 0.55, 0.25)
	controller.current_energy = 1.25
	controller.context.status_tint = Color(0.2, 0.7, 0.9, 0.35)
	controller._inject_shader_parameters()
	var uploaded_direction = a.shader_material.get_shader_parameter("light_direction")
	var uploaded_color = a.shader_material.get_shader_parameter("light_color")
	var uploaded_status = a.shader_material.get_shader_parameter("status_tint")
	check(uploaded_direction is Vector2, "Lighting controller still uploads light_direction")
	check(uploaded_color is Color and uploaded_color.is_equal_approx(controller.current_color), "Lighting controller still uploads light_color")
	check(is_equal_approx(float(a.shader_material.get_shader_parameter("light_energy")), 1.25), "Lighting controller still uploads light_energy")
	check(uploaded_status is Color and uploaded_status.is_equal_approx(controller.context.status_tint), "Status tint remains connected")
	check(controller.profile.actor_light_mask == 8, "Actor light mask remains 8")
	check(controller.profile.emissive_light_mask == 32, "Emissive light mask remains 32")

	var shader_source := FileAccess.get_file_as_string("res://shaders/mud_pixel_shader.gdshader")
	check(shader_source.find("value_noise(p / 8.0)") >= 0 and shader_source.find("floor(p)") >= 0, "Material breakup is based on local SDF coordinates")
	check(shader_source.find("TIME") < 0 and shader_source.find("SCREEN_UV") < 0, "Mud breakup has no animated or screen-space sampling")
	check(shader_source.find("vec3(0.85, 0.90, 0.65)") < 0, "Fixed plastic key color was removed")
	check(shader_source.find("shadow_to_mid") >= 0 and shader_source.find("mid_to_key") >= 0, "Shader uses explicit three-band transitions")

	var comparison_scene := preload("res://scenes/tests/lighting_test_arena.tscn").instantiate()
	root.add_child(comparison_scene)
	check(comparison_scene.get_node_or_null("NoPracticalLight") != null, "Visual comparison scene includes no-light case")
	check(comparison_scene.get_node_or_null("WeakCool") != null, "Visual comparison scene includes weak cool case")
	check(comparison_scene.get_node_or_null("WarmOverhead") != null, "Visual comparison scene includes strong warm overhead case")
	check(comparison_scene.get_node_or_null("SideLit") != null, "Visual comparison scene includes side-light case")
	check(comparison_scene.get_node_or_null("WarmCoolOverlap") != null, "Visual comparison scene includes overlapping-light case")
	comparison_scene.queue_free()

	actor_a.queue_free()
	actor_b.queue_free()
	await process_frame
	print("MUD MATERIAL RESULT: ", failures, " failures")
	quit(1 if failures else 0)
