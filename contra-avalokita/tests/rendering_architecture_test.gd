extends SceneTree

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
	print("--- Running Rendering Architecture Test Suite ---")
	test_level_template()
	await process_frame
	test_bunker_station()
	await process_frame
	
	if failures == 0:
		print("=== ALL RENDERING ARCHITECTURE TESTS PASSED ===")
		quit(0)
	else:
		push_error("=== %d TESTS FAILED ===" % failures)
		quit(1)

func test_level_template() -> void:
	print("\n-- Testing level_template.tscn --")
	var template_scene: PackedScene = preload("res://scenes/levels/level_template.tscn")
	check(template_scene != null, "level_template.tscn preloads successfully")
	var level: LevelRoot = template_scene.instantiate() as LevelRoot
	check(level != null, "level_template.tscn instantiates as LevelRoot")
	root.add_child(level)
	
	verify_domain_hierarchy(level, "LevelTemplate")
	verify_parallax_ratios(level, "LevelTemplate")
	verify_collision_ownership(level, "LevelTemplate")
	verify_z_bands(level, "LevelTemplate")
	
	level.queue_free()

func test_bunker_station() -> void:
	print("\n-- Testing bunker_station.tscn --")
	var bunker_scene: PackedScene = preload("res://scenes/levels/bunker_station.tscn")
	check(bunker_scene != null, "bunker_station.tscn preloads successfully")
	var level: LevelRoot = bunker_scene.instantiate() as LevelRoot
	check(level != null, "bunker_station.tscn instantiates as LevelRoot")
	root.add_child(level)
	
	verify_domain_hierarchy(level, "BunkerStation")
	verify_parallax_ratios(level, "BunkerStation")
	verify_collision_ownership(level, "BunkerStation")
	verify_z_bands(level, "BunkerStation")
	verify_lighting_domains(level, "BunkerStation")
	verify_runtime_apis(level, "BunkerStation")
	
	level.queue_free()

func verify_domain_hierarchy(level: LevelRoot, level_name: String) -> void:
	check(level.world != null, "%s has valid 'World' domain" % level_name)
	check(level.background_world != null, "%s has valid 'BackgroundWorld' domain" % level_name)
	check(level.gameplay_world != null, "%s has valid 'GameplayWorld' domain" % level_name)
	check(level.foreground_world != null, "%s has valid 'ForegroundWorld' domain" % level_name)
	check(level.lighting != null, "%s has valid 'Lighting' domain" % level_name)
	check(level.environment_fx != null, "%s has valid 'EnvironmentFX' domain" % level_name)
	check(level.runtime_fx != null, "%s has valid 'RuntimeFX' domain" % level_name)
	check(level.camera_rig != null, "%s has valid 'CameraRig' domain" % level_name)
	check(level.screen_fx != null and level.screen_fx.layer == 10, "%s has valid 'ScreenFX' on CanvasLayer 10" % level_name)
	check(level.ui != null and level.ui.layer == 20, "%s has valid 'UI' on CanvasLayer 20" % level_name)
	check(level.environment_controller != null, "%s has valid 'LevelEnvironmentController'" % level_name)
	check(level.player != null and level.player is MudCharacter, "%s has player under GameplayWorld" % level_name)

func verify_parallax_ratios(level: LevelRoot, level_name: String) -> void:
	var far_bg: Parallax2D = level.background_world.get_node_or_null("FarBackground") as Parallax2D
	check(far_bg != null and far_bg.scroll_scale.x >= 0.08 and far_bg.scroll_scale.x <= 0.15,
		"%s FarBackground scroll_scale.x in [0.08, 0.15] (got %s)" % [level_name, far_bg.scroll_scale if far_bg else "null"])

	var distant: Parallax2D = level.background_world.get_node_or_null("DistantStructures") as Parallax2D
	check(distant != null and distant.scroll_scale.x >= 0.18 and distant.scroll_scale.x <= 0.32,
		"%s DistantStructures scroll_scale.x in [0.18, 0.32] (got %s)" % [level_name, distant.scroll_scale if distant else "null"])

	var mid_bg: Parallax2D = level.background_world.get_node_or_null("MidBackground") as Parallax2D
	check(mid_bg != null and mid_bg.scroll_scale.x >= 0.40 and mid_bg.scroll_scale.x <= 0.60,
		"%s MidBackground scroll_scale.x in [0.40, 0.60] (got %s)" % [level_name, mid_bg.scroll_scale if mid_bg else "null"])

	var near_bg: Parallax2D = level.background_world.get_node_or_null("NearBackground") as Parallax2D
	check(near_bg != null and near_bg.scroll_scale.x >= 0.72 and near_bg.scroll_scale.x <= 0.88,
		"%s NearBackground scroll_scale.x in [0.72, 0.88] (got %s)" % [level_name, near_bg.scroll_scale if near_bg else "null"])

	var near_fg: Parallax2D = level.foreground_world.get_node_or_null("NearForeground") as Parallax2D
	check(near_fg != null and near_fg.scroll_scale.x >= 1.05 and near_fg.scroll_scale.x <= 1.15,
		"%s NearForeground scroll_scale.x in [1.05, 1.15] (got %s)" % [level_name, near_fg.scroll_scale if near_fg else "null"])

	var front_occ: Parallax2D = level.foreground_world.get_node_or_null("FrontOccluders") as Parallax2D
	check(front_occ != null and front_occ.scroll_scale.x >= 1.15 and front_occ.scroll_scale.x <= 1.30,
		"%s FrontOccluders scroll_scale.x in [1.15, 1.30] (got %s)" % [level_name, front_occ.scroll_scale if front_occ else "null"])

func verify_collision_ownership(level: LevelRoot, level_name: String) -> void:
	# Verify that GameplayWorld contains collision
	var gameplay_collisions: Array[Node] = _find_all_collision_nodes(level.gameplay_world)
	check(gameplay_collisions.size() > 0, "%s GameplayWorld contains collision shapes (%d found)" % [level_name, gameplay_collisions.size()])

	# Verify NO other domain contains collision shapes or bodies
	var non_gameplay_domains: Array[Node] = [
		level.background_world,
		level.foreground_world,
		level.lighting,
		level.environment_fx,
		level.runtime_fx,
		level.screen_fx,
		level.ui
	]

	var illegal_collisions: Array[Node] = []
	for domain: Node in non_gameplay_domains:
		if domain != null:
			illegal_collisions.append_array(_find_all_collision_nodes(domain))

	check(illegal_collisions.size() == 0,
		"%s has zero collision shapes outside GameplayWorld (found %d illegal collision nodes)" % [level_name, illegal_collisions.size()])

func _find_all_collision_nodes(root_node: Node) -> Array[Node]:
	var result: Array[Node] = []
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionShape2D or node is CollisionPolygon2D or node is CollisionObject2D:
			result.append(node)
		for child: Node in node.get_children():
			stack.push_back(child)
	return result

func verify_z_bands(level: LevelRoot, level_name: String) -> void:
	var far_bg: CanvasItem = level.background_world.get_node_or_null("FarBackground") as CanvasItem
	var mid_bg: CanvasItem = level.background_world.get_node_or_null("MidBackground") as CanvasItem
	var near_fg: CanvasItem = level.foreground_world.get_node_or_null("NearForeground") as CanvasItem
	var front_occ: CanvasItem = level.foreground_world.get_node_or_null("FrontOccluders") as CanvasItem
	var overlay: CanvasItem = level.environment_fx.get_node_or_null("AtmosphericOverlay") as CanvasItem

	check(far_bg != null and far_bg.z_index <= -80, "%s FarBackground is in Deep BG Z-band (z_index=%d)" % [level_name, far_bg.z_index if far_bg else 0])
	check(mid_bg != null and mid_bg.z_index >= -60 and mid_bg.z_index <= -35, "%s MidBackground is in Mid BG Z-band (z_index=%d)" % [level_name, mid_bg.z_index if mid_bg else 0])
	check(near_fg != null and near_fg.z_index >= 40 and near_fg.z_index <= 60, "%s NearForeground is in Foreground Z-band (z_index=%d)" % [level_name, near_fg.z_index if near_fg else 0])
	check(front_occ != null and front_occ.z_index >= 61 and front_occ.z_index <= 75, "%s FrontOccluders is in Front Occluder Z-band (z_index=%d)" % [level_name, front_occ.z_index if front_occ else 0])
	check(overlay != null and overlay.z_index >= 76, "%s AtmosphericOverlay is above front occluders (z_index=%d)" % [level_name, overlay.z_index if overlay else 0])

func verify_lighting_domains(level: LevelRoot, level_name: String) -> void:
	var global_modulate: CanvasModulate = level.lighting.get_node_or_null("GlobalLighting/CanvasModulate") as CanvasModulate
	check(global_modulate != null, "%s contains GlobalLighting/CanvasModulate" % level_name)

	var bg_lights: Node = level.lighting.get_node_or_null("BackgroundLights")
	check(bg_lights != null, "%s has BackgroundLights domain" % level_name)

	var gameplay_lights: Node = level.lighting.get_node_or_null("GameplayLights")
	check(gameplay_lights != null, "%s has GameplayLights domain" % level_name)

	var fg_lights: Node = level.lighting.get_node_or_null("ForegroundLights")
	check(fg_lights != null, "%s has ForegroundLights domain" % level_name)

	var dynamic_lights: Node = level.lighting.get_node_or_null("DynamicLights")
	check(dynamic_lights != null, "%s has DynamicLights domain" % level_name)

	# Verify cull masks on industrial lamp in gameplay lights
	var lamp: Node = gameplay_lights.get_node_or_null("StationLamp1")
	if lamp:
		var point_light: PointLight2D = lamp.get_node_or_null("PointLight2D") as PointLight2D
		check(point_light != null and (point_light.range_item_cull_mask & 12 != 0),
			"%s StationLamp1 point light illuminates gameplay geometry and actors (mask & 12 != 0)" % level_name)

func verify_runtime_apis(level: LevelRoot, level_name: String) -> void:
	# Test VFX spawning via router
	var impact_scene: PackedScene = preload("res://scenes/fx/combat_impact_fx.tscn")
	var spawned: Node2D = level.spawn_fx(impact_scene.instantiate(), VFXRouter.Channel.COMBAT, Vector2(150, 100))
	check(spawned != null, "%s level_root.spawn_fx spawns instance" % level_name)
	check(spawned != null and spawned.get_parent() == level.runtime_fx.combat_fx,
		"%s combat FX parented to RuntimeFX/CombatFX" % level_name)

	# Test dynamic light spawning
	var flash_light: Node2D = level.spawn_light_flash(Vector2(200, 100), Color.ORANGE, 2.0, 0.3)
	check(flash_light != null, "%s level_root.spawn_light_flash spawns light" % level_name)
	check(flash_light != null and flash_light.get_parent() == level.runtime_fx.dynamic_lights,
		"%s dynamic light flash parented to DynamicLights" % level_name)

	# Test camera shake request
	var initial_trauma: float = level.camera_rig.trauma
	level.request_camera_trauma(0.4)
	level.request_camera_shake(Vector2(1, 0), 0.5, 0.1)
	check(level.camera_rig.trauma > initial_trauma, "%s request_camera_trauma / shake increases trauma" % level_name)

	# Test mood transition
	if level.environment_controller:
		level.environment_controller.set_mood(LevelEnvironmentController.Mood.EMERGENCY_ALARM, true)
		check(level.environment_controller.current_mood == LevelEnvironmentController.Mood.EMERGENCY_ALARM,
			"%s LevelEnvironmentController set_mood functions properly" % level_name)

	# Test debug overlay toggle
	var debug_ui: RenderDebugOverlay = level.ui.get_node_or_null("DebugUI") as RenderDebugOverlay
	if debug_ui:
		var was_enabled: bool = debug_ui.enabled
		debug_ui.toggle()
		check(debug_ui.enabled != was_enabled, "%s RenderDebugOverlay toggles display state" % level_name)
