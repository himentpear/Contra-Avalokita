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
	test_test_arena()
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
	verify_character_local_fx(level, "LevelTemplate")
	verify_atmosphere_split(level, "LevelTemplate")
	
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
	verify_character_local_fx(level, "BunkerStation")
	verify_world_fx_ownership(level, "BunkerStation")
	verify_atmosphere_split(level, "BunkerStation")
	verify_lighting_domains(level, "BunkerStation")
	verify_emissive_policy(level, "BunkerStation")
	level.queue_free()

func test_test_arena() -> void:
	print("\n-- Testing test_arena.tscn --")
	var arena_scene: PackedScene = preload("res://scenes/test_arena.tscn")
	check(arena_scene != null, "test_arena.tscn preloads successfully")
	var level: LevelRoot = arena_scene.instantiate() as LevelRoot
	check(level != null, "test_arena.tscn instantiates as LevelRoot")
	root.add_child(level)
	
	verify_domain_hierarchy(level, "TestArena")
	verify_parallax_ratios(level, "TestArena")
	verify_collision_ownership(level, "TestArena")
	verify_z_bands(level, "TestArena")
	verify_character_local_fx(level, "TestArena")
	verify_world_fx_ownership(level, "TestArena")
	verify_atmosphere_split(level, "TestArena")
	verify_lighting_domains(level, "TestArena")
	verify_emissive_policy(level, "TestArena")
	verify_runtime_apis(level, "TestArena")
	
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
	var gameplay_collisions: Array[Node] = _find_all_collision_nodes(level.gameplay_world)
	check(gameplay_collisions.size() > 0, "%s GameplayWorld contains collision shapes (%d found)" % [level_name, gameplay_collisions.size()])

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
	var distant: CanvasItem = level.background_world.get_node_or_null("DistantStructures") as CanvasItem
	var mid_bg: CanvasItem = level.background_world.get_node_or_null("MidBackground") as CanvasItem
	var near_bg: CanvasItem = level.background_world.get_node_or_null("NearBackground") as CanvasItem
	var near_fg: CanvasItem = level.foreground_world.get_node_or_null("NearForeground") as CanvasItem
	var front_occ: CanvasItem = level.foreground_world.get_node_or_null("FrontOccluders") as CanvasItem

	check(far_bg != null and far_bg.z_index >= -100 and far_bg.z_index <= -80,
		"%s FarBackground in band [-100, -80] (z_index=%d)" % [level_name, far_bg.z_index if far_bg else 0])
	check(distant != null and distant.z_index >= -79 and distant.z_index <= -60,
		"%s DistantStructures in band [-79, -60] (z_index=%d)" % [level_name, distant.z_index if distant else 0])
	check(mid_bg != null and mid_bg.z_index >= -59 and mid_bg.z_index <= -35,
		"%s MidBackground in band [-59, -35] (z_index=%d)" % [level_name, mid_bg.z_index if mid_bg else 0])
	check(near_bg != null and near_bg.z_index >= -34 and near_bg.z_index <= -15,
		"%s NearBackground in band [-34, -15] (z_index=%d)" % [level_name, near_bg.z_index if near_bg else 0])

	# Check world runtime FX containers
	var trans_fx: Node2D = level.runtime_fx.world_transient_fx
	var proj_fx: Node2D = level.runtime_fx.projectile_fx
	var detach_fx: Node2D = level.runtime_fx.detached_character_fx
	var combat_fx: Node2D = level.runtime_fx.combat_fx

	check(trans_fx != null and trans_fx.z_index >= 13 and trans_fx.z_index <= 19,
		"%s WorldTransientFX in band [13, 19] (z_index=%d)" % [level_name, trans_fx.z_index if trans_fx else 0])
	check(proj_fx != null and proj_fx.z_index >= 20 and proj_fx.z_index <= 24,
		"%s ProjectileFX in band [20, 24] (z_index=%d)" % [level_name, proj_fx.z_index if proj_fx else 0])
	check(detach_fx != null and detach_fx.z_index >= 25 and detach_fx.z_index <= 29,
		"%s DetachedCharacterFX in band [25, 29] (z_index=%d)" % [level_name, detach_fx.z_index if detach_fx else 0])
	check(combat_fx != null and combat_fx.z_index >= 30 and combat_fx.z_index <= 39,
		"%s CombatFX in band [30, 39] (z_index=%d)" % [level_name, combat_fx.z_index if combat_fx else 0])

	check(near_fg != null and near_fg.z_index >= 40 and near_fg.z_index <= 60,
		"%s NearForeground in band [40, 60] (z_index=%d)" % [level_name, near_fg.z_index if near_fg else 0])
	check(front_occ != null and front_occ.z_index >= 61 and front_occ.z_index <= 75,
		"%s FrontOccluders in band [61, 75] (z_index=%d)" % [level_name, front_occ.z_index if front_occ else 0])

func verify_character_local_fx(level: LevelRoot, level_name: String) -> void:
	var player: MudCharacter = level.player
	check(player != null, "%s has valid Player instance" % level_name)
	if not player: return

	check(player.local_fx_behind != null, "%s player exposes LocalFXBehind socket" % level_name)
	check(player.local_fx_body != null, "%s player exposes LocalFXBody socket" % level_name)
	check(player.local_fx_front != null, "%s player exposes LocalFXFront socket" % level_name)

	# Validate socket Z bands
	check(player.local_fx_behind.z_index >= -14 and player.local_fx_behind.z_index <= -8,
		"%s LocalFXBehind in band [-14, -8] (z_index=%d)" % [level_name, player.local_fx_behind.z_index])
	check(player.local_fx_body.z_index >= 8 and player.local_fx_body.z_index <= 12,
		"%s LocalFXBody in band [8, 12] (z_index=%d)" % [level_name, player.local_fx_body.z_index])
	check(player.local_fx_front.z_index >= 25 and player.local_fx_front.z_index <= 29,
		"%s LocalFXFront in band [25, 29] (z_index=%d)" % [level_name, player.local_fx_front.z_index])

	# Test spawning local effect attached to character
	var aura := Node2D.new()
	var spawned_local := level.spawn_character_fx(player, aura, VFXRouter.LocalChannel.BODY, Vector2(0, -10))
	check(spawned_local != null and spawned_local.get_parent() == player.local_fx_body,
		"%s spawn_character_fx attaches effect rigidly to player local socket" % level_name)
	aura.queue_free()

func verify_world_fx_ownership(level: LevelRoot, level_name: String) -> void:
	var player: MudCharacter = level.player
	# Test spawning world transient effect
	var dust := Node2D.new()
	var spawned_dust := level.spawn_world_fx(dust, VFXRouter.WorldChannel.WORLD_TRANSIENT, Vector2(100, 150))
	check(spawned_dust != null and spawned_dust.get_parent() == level.runtime_fx.world_transient_fx,
		"%s spawn_world_fx parents dust to RuntimeFX/WorldTransientFX" % level_name)
	check(spawned_dust != null and spawned_dust.get_parent() != player,
		"%s world transient effect is strictly NOT parented to Player" % level_name)
	dust.queue_free()

func verify_atmosphere_split(level: LevelRoot, level_name: String) -> void:
	# World atmosphere: inside EnvironmentFX with real depth / parallax
	var far_fx: Node2D = level.environment_fx.get_node_or_null("FarFX") as Node2D
	var mid_fx: Node2D = level.environment_fx.get_node_or_null("MidFX") as Node2D
	var gameplay_fx: Node2D = level.environment_fx.get_node_or_null("GameplayWorldFX") as Node2D
	var near_fx: Node2D = level.environment_fx.get_node_or_null("NearFX") as Node2D

	check(far_fx != null and mid_fx != null and gameplay_fx != null and near_fx != null,
		"%s EnvironmentFX contains FarFX, MidFX, GameplayWorldFX, NearFX depth channels" % level_name)

	# Verify no world-space AtmosphericOverlay Polygon2D exists
	var world_overlay: Node = level.environment_fx.get_node_or_null("AtmosphericOverlay")
	check(world_overlay == null, "%s does not use world-space Polygon2D for screen atmosphere" % level_name)

	# Screen atmosphere: inside ScreenFX (CanvasLayer 10)
	var screen_atm: ColorRect = level.screen_fx.get_node_or_null("ScreenAtmosphere") as ColorRect
	check(screen_atm != null, "%s ScreenAtmosphere exists as ColorRect on CanvasLayer 10" % level_name)

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

func verify_emissive_policy(level: LevelRoot, level_name: String) -> void:
	var gameplay_lights: Node = level.lighting.get_node_or_null("GameplayLights")
	var lamp: Node = gameplay_lights.get_node_or_null("StationLamp1") if gameplay_lights else null
	if lamp:
		var housing: Node = lamp.get_node_or_null("Housing")
		var bulb: CanvasItem = lamp.get_node_or_null("BulbVisual") as CanvasItem
		var glow: CanvasItem = lamp.get_node_or_null("GlowVisual") as CanvasItem
		var point_light: PointLight2D = lamp.get_node_or_null("PointLight2D") as PointLight2D

		check(housing != null, "%s IndustrialLamp separates structural Housing" % level_name)
		check(bulb != null and bulb.light_mask == 32, "%s BulbVisual uses light_mask=32 (EMISSIVE_VISUAL)" % level_name)
		check(glow != null and glow.material is CanvasItemMaterial and (glow.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
			"%s GlowVisual uses additive blending for visible glow" % level_name)
		check(point_light != null and (point_light.range_item_cull_mask & 12 != 0),
			"%s PointLight2D illuminates gameplay geometry and actors via range_item_cull_mask" % level_name)

func verify_runtime_apis(level: LevelRoot, level_name: String) -> void:
	# Test VFX spawning via router
	var impact_scene: PackedScene = preload("res://scenes/fx/combat_impact_fx.tscn")
	var spawned: Node2D = level.spawn_world_fx(impact_scene.instantiate(), VFXRouter.WorldChannel.COMBAT, Vector2(150, 100))
	check(spawned != null, "%s level_root.spawn_world_fx spawns combat instance" % level_name)
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

	# Test mood transition with screen atmosphere
	if level.environment_controller:
		level.environment_controller.set_mood(LevelEnvironmentController.Mood.EMERGENCY_ALARM, true)
		check(level.environment_controller.current_mood == LevelEnvironmentController.Mood.EMERGENCY_ALARM,
			"%s LevelEnvironmentController set_mood functions properly" % level_name)
		if level.environment_controller.screen_atmosphere:
			check(level.environment_controller.screen_atmosphere.color.r > 0.3,
				"%s EMERGENCY_ALARM mood applies red screen atmosphere veil" % level_name)

	# Test debug overlay toggle
	var debug_ui: RenderDebugOverlay = level.ui.get_node_or_null("DebugUI") as RenderDebugOverlay
	if debug_ui:
		var was_enabled: bool = debug_ui.enabled
		debug_ui.toggle()
		check(debug_ui.enabled != was_enabled, "%s RenderDebugOverlay toggles display state" % level_name)
