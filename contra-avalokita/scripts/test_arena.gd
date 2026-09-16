extends LevelRoot

const CHARACTER := preload("res://scenes/mud_character.tscn")
const DUMMY := preload("res://scripts/training_dummy.gd")
const TEST_DUMMY := preload("res://scripts/test_dummy_target.gd")
const Glyphs := preload("res://scripts/six_realm_glyphs.gd")
const ITEM_PICKUP := preload("res://scripts/coyote_item_pickup.gd")
const ENEMY_CONTROLLER := preload("res://scripts/training_enemy_controller.gd")
const COYOTE_ITEMS: Array[CoyoteItem] = [
	preload("res://content/base/items/coyote/wile_glance.tres"),
	preload("res://content/base/items/coyote/suspended_absurdity.tres"),
	preload("res://content/base/items/coyote/hermes_winged_boots.tres"),
	preload("res://content/base/items/coyote/dear_cruel_gravity.tres"),
	preload("res://content/base/items/coyote/three_eyed_pardon.tres"),
]

const MAIN_SURFACE_Y := 138.0
const TEST_KILL_Y := 480.0

@export_group("Arena Presentation")
@export var background_color := Color("1a222c")
@export_range(-1200.0, 300.0, 1.0) var camera_center_y := 0.0
@export var camera_shake_enabled := false
@export_group("")

# Node references & domain aliases
var world_node: Node2D
var background_node: Node2D
var geometry_node: Node2D
var markers_node: Node2D
var actors_node: Node2D
var checkpoints_node: Node2D
var hud_layer: CanvasLayer
var tactical_overlay: Control
var item_console: PanelContainer
var item_gallery: Control
var camera: Camera2D

# Actors & Entities (player is inherited from LevelRoot)
var dummy: Node2D # Persistent dummy for backward compatibility
var stationary_dummy: CharacterBody2D
var blocking_dummy: CharacterBody2D
var damage_dummy: CharacterBody2D
var knockback_dummy: CharacterBody2D
var ledge_dummy: CharacterBody2D
var scoring_enemy: MudCharacter
var crowd: Array[MudCharacter] = []
var real_enemies: Array[MudCharacter] = []
var item_pickups: Array[Node] = []
var checkpoints: Array[Vector2] = []

# State & Telemetry
var show_stats_panel := true
var show_item_console := true
var crowd_mode := 0
var elapsed := 0.0
var frame := 0
var font: Font
var pickup_notice := ""
var pickup_notice_left := 0.0
var knockback_feedback := ""
var knockback_feedback_left := 0.0

# Camera shake
var camera_shake_offset := Vector2.ZERO
var camera_shake_timer := 0.0
var camera_shake_duration := 0.0
var camera_shake_dir := Vector2.RIGHT
var camera_shake_amp := 0.0

func _enter_tree() -> void:
	bind("move_left", [KEY_A, KEY_LEFT])
	bind("move_right", [KEY_D, KEY_RIGHT])
	bind("jump", [KEY_SPACE])
	bind("sprint", [KEY_SHIFT])
	bind("attack", [KEY_J])
	bind("block", [KEY_L])
	bind("equipment", [KEY_E])
	bind("weapon_sword", [KEY_1])
	bind("weapon_none", [KEY_2])
	bind("debug_rig", [KEY_F1])
	bind("debug_stats", [KEY_F1])
	bind("toggle_item_console", [KEY_F2])
	bind("spawn_enemy", [KEY_F3])
	bind("score_realm", [KEY_F4])
	bind("toggle_details", [KEY_F5])
	bind("toggle_coyote_items", [KEY_F6])
	bind("reset", [KEY_R])
	bind("kill", [KEY_K])
	bind("crowd", [KEY_T])
	bind("shake_toggle", [KEY_C])
	
	# Teleport hotkeys: 1-6
	bind("tp_zone_1", [KEY_1])
	bind("tp_zone_2", [KEY_2])
	bind("tp_zone_3", [KEY_3])
	bind("tp_zone_4", [KEY_4])
	bind("tp_zone_5", [KEY_5])
	bind("tp_zone_6", [KEY_6])
	
	# Knockback test triggers: 7, 8, 9
	bind("knockback_weak", [KEY_7])
	bind("knockback_medium", [KEY_8])
	bind("knockback_heavy", [KEY_9])
	
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", click)

func bind(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action): return
	InputMap.add_action(action)
	for code in keys:
		var event := InputEventKey.new()
		event.physical_keycode = code
		InputMap.action_add_event(action, event)

func _get_score_system() -> Node:
	return get_tree().get_first_node_in_group(&"score_system") if is_inside_tree() else null

func _ready() -> void:
	super._ready()
	font = preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
	apply_render_policies()
	
	if gameplay_world != null and (player != null or gameplay_world.has_node("Player")):
		_setup_from_scene_tree()
	else:
		# Programmatic fallback when instantiated as standalone TestArena.new()
		_build_world_hierarchy()
		_build_geometry()
		_setup_checkpoints()
		_spawn_actors()
		_build_camera()
		_build_ui()
	
	var game := get_node_or_null("/root/Game")
	if game and is_instance_valid(game.current_session) and game.current_session.has_method("set_player") and is_instance_valid(player):
		game.current_session.set_player(player)

func _setup_from_scene_tree() -> void:
	world_node = world
	background_node = background_world
	if gameplay_world:
		geometry_node = gameplay_world.get_node_or_null("StaticGeometry")
		markers_node = gameplay_world.get_node_or_null("Markers")
		actors_node = gameplay_world.get_node_or_null("TestActors")
		checkpoints_node = gameplay_world.get_node_or_null("Checkpoints")
	
	# Scene checkpoints are the source of truth so moving them in the editor also
	# updates number-key teleporting and respawn positions.
	checkpoints.clear()
	if checkpoints_node:
		for child in checkpoints_node.get_children():
			var checkpoint := child as Node2D
			if checkpoint:
				checkpoints.append(gameplay_world.to_local(checkpoint.global_position))
	if checkpoints.is_empty():
		_setup_checkpoints()
	
	if actors_node:
		dummy = actors_node.get_node_or_null("Dummy")
		stationary_dummy = actors_node.get_node_or_null("StationaryDummy")
		blocking_dummy = actors_node.get_node_or_null("BlockingDummy")
		damage_dummy = actors_node.get_node_or_null("DamageDummy")
		knockback_dummy = actors_node.get_node_or_null("KnockbackDummy")
		ledge_dummy = actors_node.get_node_or_null("LedgeDummy")
	
	item_pickups.clear()
	var pickups_container: Node = gameplay_world.get_node_or_null("ItemPickups") if gameplay_world else null
	if pickups_container:
		for child in pickups_container.get_children():
			item_pickups.append(child)
			if child.has_signal("collected") and not child.collected.is_connected(_on_item_collected):
				child.collected.connect(_on_item_collected)
	
	if not player and gameplay_world:
		player = gameplay_world.get_node_or_null("Player") as MudCharacter
	if player:
		player.movement_assist_debug = true
	
	if camera_rig and camera_rig.camera:
		camera = camera_rig.camera
	else:
		camera = get_node_or_null("CameraRig/Camera2D") as Camera2D
	
	hud_layer = ui
	if ui:
		tactical_overlay = ui.get_node_or_null("HUD/TacticalOverlay") as Control
		if tactical_overlay and not tactical_overlay.draw.is_connected(_on_tactical_overlay_draw):
			tactical_overlay.draw.connect(_on_tactical_overlay_draw)
		
		item_console = ui.get_node_or_null("HUD/ItemConsole") as PanelContainer
		_wire_item_console()
		
		item_gallery = ui.get_node_or_null("HUD/ItemGallery") as Control

func _wire_item_console() -> void:
	if not is_instance_valid(item_console): return
	for i in COYOTE_ITEMS.size():
		var cb := item_console.find_child("ItemCheck_%d" % i, true, false) as CheckBox
		if cb and not cb.toggled.is_connected(_on_item_check_toggled.bind(i)):
			cb.toggled.connect(_on_item_check_toggled.bind(i))
	
	var btn_reset := item_console.find_child("BtnReset", true, false) as Button
	if btn_reset and not btn_reset.pressed.is_connected(_on_console_reset_pressed):
		btn_reset.pressed.connect(_on_console_reset_pressed)
		
	var btn_all := item_console.find_child("BtnAll", true, false) as Button
	if btn_all and not btn_all.pressed.is_connected(_on_console_all_pressed):
		btn_all.pressed.connect(_on_console_all_pressed)

func _on_item_check_toggled(active: bool, index: int) -> void:
	if not is_instance_valid(player) or index < 0 or index >= COYOTE_ITEMS.size(): return
	var item := COYOTE_ITEMS[index]
	if active and not player.item_inventory.has(item.id):
		player.obtain_item(item)
	elif not active and player.item_inventory.has(item.id):
		player.remove_item(item.id)

func _on_console_reset_pressed() -> void:
	if is_instance_valid(player):
		player.item_inventory.clear()
		_refresh_item_console_checks()

func _on_console_all_pressed() -> void:
	if is_instance_valid(player):
		for item in COYOTE_ITEMS:
			player.obtain_item(item)
		_refresh_item_console_checks()

func has_station_background() -> bool:
	var bg_parent: Node = background_world if background_world else background_node
	if not bg_parent:
		return false
	for s in bg_parent.find_children("*", "Sprite2D", true, false):
		var sprite := s as Sprite2D
		if sprite and sprite.texture and (sprite.texture.resource_path.ends_with("stationBG.png") or sprite.texture.resource_path.ends_with("horizon.png")):
			return true
	for t in bg_parent.find_children("*", "TextureRect", true, false):
		var tr := t as TextureRect
		if tr and tr.texture and (tr.texture.resource_path.ends_with("stationBG.png") or tr.texture.resource_path.ends_with("horizon.png")):
			return true
	return false

func _build_world_hierarchy() -> void:
	world_node = Node2D.new()
	world_node.name = "World"
	add_child(world_node)
	world = world_node
	
	background_node = Node2D.new()
	background_node.name = "BackgroundWorld"
	world_node.add_child(background_node)
	background_world = background_node
	
	var far_bg := Parallax2D.new()
	far_bg.name = "FarBackground"
	far_bg.scroll_scale = Vector2(0.12, 1.0)
	far_bg.z_index = -90
	far_bg.repeat_size = Vector2(869, 0)
	far_bg.repeat_times = 10
	background_node.add_child(far_bg)
	
	var bg_sprite := Sprite2D.new()
	bg_sprite.name = "StationBG"
	bg_sprite.texture = preload("res://scenes/levels/stationBG.png")
	bg_sprite.position = Vector2(0, -60)
	bg_sprite.centered = false
	far_bg.add_child(bg_sprite)
	
	gameplay_world = Node2D.new()
	gameplay_world.name = "GameplayWorld"
	world_node.add_child(gameplay_world)
	
	geometry_node = Node2D.new()
	geometry_node.name = "StaticGeometry"
	gameplay_world.add_child(geometry_node)
	
	markers_node = Node2D.new()
	markers_node.name = "Markers"
	markers_node.z_index = -2
	gameplay_world.add_child(markers_node)
	
	actors_node = Node2D.new()
	actors_node.name = "TestActors"
	gameplay_world.add_child(actors_node)
	
	checkpoints_node = Node2D.new()
	checkpoints_node.name = "Checkpoints"
	gameplay_world.add_child(checkpoints_node)

func platform(center: Vector2, size: Vector2, col: Color = Color("707882"), edge_col: Color = Color("d4dae0")) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	
	var surface := Polygon2D.new()
	surface.name = "Surface"
	surface.polygon = PackedVector2Array([
		-size * 0.5, Vector2(size.x * 0.5, -size.y * 0.5),
		size * 0.5, Vector2(-size.x * 0.5, size.y * 0.5)
	])
	surface.color = col
	surface.z_index = -5
	body.add_child(surface)
	
	var edge := Line2D.new()
	edge.name = "TopEdge"
	edge.points = PackedVector2Array([Vector2(-size.x * 0.5, -size.y * 0.5), Vector2(size.x * 0.5, -size.y * 0.5)])
	edge.width = 1.0
	edge.default_color = edge_col
	edge.z_index = -4
	body.add_child(edge)
	
	geometry_node.add_child(body)
	return body

func training_platform(center: Vector2, size: Vector2, col: Color = Color("4e9fa8")) -> StaticBody2D:
	var body := platform(center, size, col, Color("8ae2ec"))
	body.add_to_group(&"climbable_surface")
	return body

func _build_geometry() -> void:
	# Left outer boundary wall
	platform(Vector2(-12, 0), Vector2(24, 600), Color("3d444c"))
	
	# =========================================================================
	# ZONE 01: BASELINE LOCOMOTION TRACK & FACING SYMMETRY (X: 0 to 800)
	# =========================================================================
	# Baseline Main Floor: Surface Y = 138, bottom Y = 158
	platform(Vector2(400, 148), Vector2(800, 20))
	# Legacy compatibility floor at Y=284 (for punch_attack_test etc.)
	platform(Vector2(435, 303), Vector2(900, 38))
	
	# =========================================================================
	# ZONE 02: COYOTE TIMING STEPS (X: 860 to 1400)
	# =========================================================================
	# Lower floor under coyote steps: Surface Y = 160
	platform(Vector2(1130, 176), Vector2(560, 32))
	
	# Ledge A: Normal walk-off ledge (X: 860 to 980, Surface Y = 64)
	platform(Vector2(920, 80), Vector2(120, 32))
	# Ledge B: Running walk-off ledge (X: 1040 to 1200, Surface Y = 64)
	platform(Vector2(1120, 80), Vector2(160, 32))
	# Ledge C: Attack walk-off ledge (X: 1260 to 1380, Surface Y = 64)
	platform(Vector2(1320, 80), Vector2(120, 32))
	
	# =========================================================================
	# ZONE 06: GRAVITY DROP LABORATORY (X: 1420 to 1540)
	# =========================================================================
	# High drop platform at Y = -48 (drop 208 px to floor Y = 160)
	platform(Vector2(1480, -32), Vector2(120, 32))
	# Drop shaft floor: Surface Y = 160
	platform(Vector2(1500, 176), Vector2(160, 32))
	
	# =========================================================================
	# ZONE 03: HORIZONTAL GAP CALIBRATION (Identical Surface Y = 128)
	# Gaps: 48, 64, 80, 96, 112, 128, 160 px
	# =========================================================================
	# Platform 0: width 80 (X: 1580 to 1660)
	platform(Vector2(1620, 144), Vector2(80, 32))
	# Gap 1 (48 px) -> Platform 1: width 64 (X: 1708 to 1772)
	platform(Vector2(1740, 144), Vector2(64, 32))
	# Gap 2 (64 px) -> Platform 2: width 64 (X: 1836 to 1900)
	platform(Vector2(1868, 144), Vector2(64, 32))
	# Gap 3 (80 px) -> Platform 3: width 64 (X: 1980 to 2044)
	platform(Vector2(2012, 144), Vector2(64, 32))
	# Gap 4 (96 px) -> Platform 4: width 64 (X: 2140 to 2204)
	platform(Vector2(2172, 144), Vector2(64, 32))
	# Gap 5 (112 px) -> Platform 5: width 64 (X: 2316 to 2380)
	platform(Vector2(2348, 144), Vector2(64, 32))
	# Gap 6 (128 px) -> Platform 6: width 64 (X: 2508 to 2572)
	platform(Vector2(2540, 144), Vector2(64, 32))
	# Gap 7 (160 px) -> Platform 7: width 80 (X: 2732 to 2812)
	platform(Vector2(2772, 144), Vector2(80, 32))
	
	# Lower safety/recovery floor under gap calibration (Surface Y = 240)
	platform(Vector2(2200, 256), Vector2(1300, 32), Color("3d444c"))
	
	# =========================================================================
	# ZONE 11: SMALL PLATFORM PRECISION ARRAY (Surface Y = 192)
	# Widths: 96, 64, 48, 32 px with equal 48 px gaps
	# =========================================================================
	# P1 (96 px): X: 1640 to 1736
	platform(Vector2(1688, 208), Vector2(96, 32))
	# P2 (64 px): X: 1784 to 1848
	platform(Vector2(1816, 208), Vector2(64, 32))
	# P3 (48 px): X: 1896 to 1944
	platform(Vector2(1920, 208), Vector2(48, 32))
	# P4 (32 px): X: 1992 to 2024
	platform(Vector2(2008, 208), Vector2(32, 32))
	
	# =========================================================================
	# ZONE 04: JUMP BUFFER LANDING STAIRCASE & ZONE 05: HEIGHT CALIBRATION
	# =========================================================================
	# High drop platform at Y = -48 for deliberate early/buffered/late buffer test
	platform(Vector2(2870, -32), Vector2(80, 32))
	# Staircase descending steps:
	# Step 1: Surface Y = 32
	platform(Vector2(2952, 48), Vector2(64, 32))
	# Step 2: Surface Y = 64
	platform(Vector2(3032, 80), Vector2(64, 32))
	# Step 3: Surface Y = 96
	platform(Vector2(3112, 112), Vector2(64, 32))
	# Step 4: Surface Y = 128
	platform(Vector2(3192, 144), Vector2(64, 32))
	# Step 5 / Ground: Surface Y = 160
	platform(Vector2(3272, 176), Vector2(80, 32))
	
	# Low ceiling test platform (X: 3260 to 3360, floor Y=160, ceiling Y=106, clearance 54 px)
	platform(Vector2(3310, 98), Vector2(100, 16), Color("5a626a"))
	
	# =========================================================================
	# ZONE 07: WALL MECHANICS TOWER (X: 3380 to 3660)
	# =========================================================================
	# Ground floor: Surface Y = 160
	platform(Vector2(3520, 176), Vector2(300, 32))
	# Left climbable wall (X = 3420, height 260 from Y = -100 to 160)
	training_platform(Vector2(3420, 30), Vector2(16, 260))
	# Right climbable wall (X = 3484, height 260 from Y = -100 to 160, shaft width 48 px)
	training_platform(Vector2(3484, 30), Vector2(16, 260))
	# Top bridge surface (Surface Y = -100)
	training_platform(Vector2(3510, -92), Vector2(200, 16))
	# Single isolated dual-face wall (X = 3580, height 200 from Y = -40 to 160)
	training_platform(Vector2(3580, 60), Vector2(16, 200))
	
	# =========================================================================
	# ZONE 08: COMBAT TEST FLOOR, ZONE 09: LEDGE COMBAT & ZONE 10: KNOCKBACK EDGE
	# =========================================================================
	# Combat Main Floor: X: 3680 to 4250, Surface Y = 160 (width 570 px)
	platform(Vector2(3965, 176), Vector2(570, 32), Color("7a6b8f"), Color("b5a2cc"))
	# Knockback platform: X: 4280 to 4420, Surface Y = 160 (edge at X = 4420, vertical drop)
	platform(Vector2(4350, 176), Vector2(140, 32), Color("8f5b5b"), Color("cc9292"))
	
	# Right outer boundary wall
	platform(Vector2(4460, 0), Vector2(24, 600), Color("3d444c"))

func _setup_checkpoints() -> void:
	checkpoints = [
		Vector2(400, 136),   # 1: Baseline & Symmetry
		Vector2(900, 62),    # 2: Coyote Steps & Gravity Drop
		Vector2(1620, 126),  # 3: Gaps & Precision Array
		Vector2(2952, 30),   # 4: Jump Buffer & Height Wall
		Vector2(3452, 158),  # 5: Wall Mechanics Tower
		Vector2(3780, 158),  # 6: Combat Arena & Knockback
	]

func _spawn_actors() -> void:
	# 1. Player
	player = CHARACTER.instantiate()
	player.name = "Player"
	player.position = checkpoints[0]
	gameplay_world.add_child(player)
	player.movement_assist_debug = true
	
	# 2. Legacy Dummy for punch_attack_test & compatibility
	dummy = Node2D.new()
	dummy.name = "Dummy"
	dummy.set_script(DUMMY)
	dummy.position = Vector2(411, 136)
	actors_node.add_child(dummy)
	
	# 3. Dedicated Combat Laboratory Dummies
	stationary_dummy = TEST_DUMMY.new()
	stationary_dummy.name = "StationaryDummy"
	stationary_dummy.dummy_type = TEST_DUMMY.DummyType.STATIONARY
	stationary_dummy.position = Vector2(3780, 158)
	actors_node.add_child(stationary_dummy)
	
	blocking_dummy = TEST_DUMMY.new()
	blocking_dummy.name = "BlockingDummy"
	blocking_dummy.dummy_type = TEST_DUMMY.DummyType.BLOCKING
	blocking_dummy.position = Vector2(3880, 158)
	actors_node.add_child(blocking_dummy)
	
	damage_dummy = TEST_DUMMY.new()
	damage_dummy.name = "DamageDummy"
	damage_dummy.dummy_type = TEST_DUMMY.DummyType.DAMAGE
	damage_dummy.position = Vector2(3980, 158)
	actors_node.add_child(damage_dummy)
	
	knockback_dummy = TEST_DUMMY.new()
	knockback_dummy.name = "KnockbackDummy"
	knockback_dummy.dummy_type = TEST_DUMMY.DummyType.KNOCKBACK
	knockback_dummy.position = Vector2(4080, 158)
	actors_node.add_child(knockback_dummy)
	
	# 4. Ledge Combat Dummy (at X=4230, right before ledge X=4250)
	ledge_dummy = TEST_DUMMY.new()
	ledge_dummy.name = "LedgeDummy"
	ledge_dummy.dummy_type = TEST_DUMMY.DummyType.STATIONARY
	ledge_dummy.position = Vector2(4230, 158)
	actors_node.add_child(ledge_dummy)
	
	# 5. Five Item Pickups in baseline area (X: 80 to 280) for real station collection test
	spawn_item_pickups()

func spawn_item_pickups() -> void:
	for pickup in item_pickups:
		if is_instance_valid(pickup): pickup.queue_free()
	item_pickups.clear()
	var parent_node: Node = gameplay_world.get_node_or_null("ItemPickups") if gameplay_world else null
	if not parent_node: parent_node = gameplay_world if gameplay_world else (world_node if world_node else self)
	for i in COYOTE_ITEMS.size():
		var pickup: Node = ITEM_PICKUP.new()
		pickup.name = "ItemPickup_%02d" % (i + 1)
		pickup.item = COYOTE_ITEMS[i]
		pickup.content_id = COYOTE_ITEMS[i].id
		pickup.position = Vector2(80.0 + i * 48.0, 124.0)
		pickup.collected.connect(_on_item_collected)
		parent_node.add_child(pickup)
		item_pickups.append(pickup)

func _on_item_collected(item: CoyoteItem) -> void:
	pickup_notice = "PICKED UP: %s // %s" % [item.display_name, item.mechanical_text.replace("\n", " ")]
	pickup_notice_left = 3.0

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.0, 1.0)
	camera.limit_left = -200
	camera.limit_top = -600
	camera.limit_right = 4600
	camera.limit_bottom = 520
	camera.position_smoothing_enabled = false
	camera.position = Vector2(player.position.x, camera_center_y)
	add_child(camera)

func _build_ui() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	hud_layer.layer = 5
	add_child(hud_layer)
	
	tactical_overlay = Control.new()
	tactical_overlay.name = "TacticalOverlay"
	tactical_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tactical_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	tactical_overlay.draw.connect(_on_tactical_overlay_draw)
	hud_layer.add_child(tactical_overlay)
	
	# Item Test Console Panel (Docked top-right)
	_build_item_console()
	
	# Item Gallery Modal
	item_gallery = preload("res://ui/items/coyote_item_gallery.tscn").instantiate()
	item_gallery.position = Vector2(48, 58)
	item_gallery.scale = Vector2.ONE * 0.68
	item_gallery.visible = false
	hud_layer.add_child(item_gallery)

func _build_item_console() -> void:
	item_console = PanelContainer.new()
	item_console.name = "ItemConsole"
	item_console.position = Vector2(440, 52)
	item_console.custom_minimum_size = Vector2(190, 180)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	item_console.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)
	
	var title := Label.new()
	title.text = "ITEM MODIFIER CONSOLE"
	title.add_theme_color_override("font_color", Color("c1d18b"))
	vbox.add_child(title)
	
	for i in COYOTE_ITEMS.size():
		var item := COYOTE_ITEMS[i]
		var cb := CheckBox.new()
		cb.text = item.display_name
		cb.name = "ItemCheck_%d" % i
		cb.toggled.connect(func(active: bool) -> void:
			if not is_instance_valid(player): return
			if active and not player.item_inventory.has(item.id):
				player.obtain_item(item)
			elif not active and player.item_inventory.has(item.id):
				player.remove_item(item.id)
		)
		vbox.add_child(cb)
	
	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)
	
	var btn_reset := Button.new()
	btn_reset.text = "RESET"
	btn_reset.pressed.connect(func() -> void:
		if is_instance_valid(player):
			player.item_inventory.clear()
			_refresh_item_console_checks()
	)
	hbox.add_child(btn_reset)
	
	var btn_all := Button.new()
	btn_all.text = "ALL ITEMS"
	btn_all.pressed.connect(func() -> void:
		if is_instance_valid(player):
			for item in COYOTE_ITEMS:
				player.obtain_item(item)
			_refresh_item_console_checks()
	)
	hbox.add_child(btn_all)
	
	hud_layer.add_child(item_console)

func _refresh_item_console_checks() -> void:
	if not is_instance_valid(item_console) or not is_instance_valid(player): return
	for i in COYOTE_ITEMS.size():
		var cb := item_console.find_child("ItemCheck_%d" % i, true, false) as CheckBox
		if cb:
			cb.set_pressed_no_signal(player.item_inventory.has(COYOTE_ITEMS[i].id))

func teleport_to_zone(zone_idx: int) -> void:
	if zone_idx < 0 or zone_idx >= checkpoints.size() or not is_instance_valid(player):
		return
	player.revive()
	player.position = checkpoints[zone_idx]
	player.velocity = Vector2.ZERO

func apply_developer_knockback(force: float, is_heavy := false) -> void:
	if not is_instance_valid(player): return
	var hit := HitEvent.new()
	hit.attacker = null
	hit.damage = 10.0
	hit.direction = Vector2.RIGHT
	hit.impact_force = force
	hit.poise_damage = 30.0 if not is_heavy else 100.0
	hit.hit_type = &"HeavyHit" if is_heavy else &"LightHit"
	hit.target_push_distance = 3.0 if not is_heavy else 6.0
	player.receive_hit(hit)
	knockback_feedback = "APPLIED KNOCKBACK: FORCE = %.0f  HEAVY = %s" % [force, str(is_heavy)]
	knockback_feedback_left = 2.0

func trigger_camera_shake(dir: Vector2, amp: float, duration: float = 0.08) -> void:
	if not camera_shake_enabled:
		camera_shake_offset = Vector2.ZERO
		if camera: camera.offset = Vector2.ZERO
		return
	camera_shake_dir = dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	camera_shake_amp = amp
	camera_shake_duration = maxf(duration, 0.001)
	camera_shake_timer = camera_shake_duration
	camera_shake_offset = camera_shake_dir * amp
	if camera: camera.offset = camera_shake_offset

func _process(delta: float) -> void:
	elapsed += delta
	frame += 1
	pickup_notice_left = maxf(0.0, pickup_notice_left - delta)
	knockback_feedback_left = maxf(0.0, knockback_feedback_left - delta)
	
	# Camera tracking
	if is_instance_valid(player) and is_instance_valid(camera):
		var target_x := player.global_position.x
		camera.global_position.x = lerpf(camera.global_position.x, target_x, 1.0 - exp(-12.0 * delta))
		camera.global_position.y = camera_center_y
		
		if camera_shake_enabled and camera_shake_timer > 0.0:
			camera_shake_timer = maxf(0.0, camera_shake_timer - delta)
			var p: float = camera_shake_timer / camera_shake_duration
			var offset_val: float = cos((camera_shake_duration - camera_shake_timer) * 55.0) * camera_shake_amp * p
			camera_shake_offset = camera_shake_dir * offset_val
			camera.offset = camera_shake_offset
		else:
			camera_shake_offset = Vector2.ZERO
			camera.offset = Vector2.ZERO
	
	if not is_instance_valid(player): return
	
	# Respawn on falling below TEST_KILL_Y
	if player.global_position.y > TEST_KILL_Y:
		var nearest_idx := 0
		var min_dist := INF
		for i in checkpoints.size():
			var dist := absf(player.global_position.x - checkpoints[i].x)
			if dist < min_dist:
				min_dist = dist
				nearest_idx = i
		teleport_to_zone(nearest_idx)
	
	# Input shortcuts
	if Input.is_action_just_pressed("debug_stats"):
		show_stats_panel = not show_stats_panel
	if Input.is_action_just_pressed("toggle_item_console"):
		show_item_console = not show_item_console
		item_console.visible = show_item_console
	if Input.is_action_just_pressed("toggle_coyote_items"):
		item_gallery.visible = not item_gallery.visible
	if Input.is_action_just_pressed("shake_toggle"):
		camera_shake_enabled = not camera_shake_enabled
	if Input.is_action_just_pressed("kill"):
		player.die()
	if player.state == &"Dead" and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack")):
		player.rise()
	if Input.is_action_just_pressed("reset"):
		# Revive at nearest checkpoint without erasing inventory
		var nearest_idx := 0
		var min_dist := INF
		for i in checkpoints.size():
			var dist := absf(player.global_position.x - checkpoints[i].x)
			if dist < min_dist:
				min_dist = dist
				nearest_idx = i
		teleport_to_zone(nearest_idx)
		for pickup in item_pickups:
			if is_instance_valid(pickup): pickup.reset_pickup()
		for d in [stationary_dummy, blocking_dummy, damage_dummy, knockback_dummy, ledge_dummy]:
			if is_instance_valid(d): d.reset_state(d.global_position)
	
	# Zone Teleport shortcuts (1-6)
	if Input.is_key_pressed(KEY_1): teleport_to_zone(0)
	elif Input.is_key_pressed(KEY_2): teleport_to_zone(1)
	elif Input.is_key_pressed(KEY_3): teleport_to_zone(2)
	elif Input.is_key_pressed(KEY_4): teleport_to_zone(3)
	elif Input.is_key_pressed(KEY_5): teleport_to_zone(4)
	elif Input.is_key_pressed(KEY_6): teleport_to_zone(5)
	
	# Knockback test keys: 7, 8, 9
	if Input.is_action_just_pressed("knockback_weak"):
		apply_developer_knockback(55.0, false)
	elif Input.is_action_just_pressed("knockback_medium"):
		apply_developer_knockback(90.0, false)
	elif Input.is_action_just_pressed("knockback_heavy"):
		apply_developer_knockback(135.0, true)
	
	if Input.is_action_just_pressed("crowd"):
		cycle_crowd()
	
	for i in crowd.size():
		var npc := crowd[i]
		if is_instance_valid(npc) and crowd_mode > 0:
			npc.set_intent(sin(elapsed * 0.7 + i) * 0.25, false, fmod(elapsed + i * 0.2, 2.1) < delta)
	
	# Sync UI Checkbox states
	_refresh_item_console_checks()
	
	if is_instance_valid(tactical_overlay):
		tactical_overlay.queue_redraw()

func cycle_crowd() -> void:
	crowd_mode = (crowd_mode + 1) % 3
	for npc in crowd:
		if is_instance_valid(npc): npc.queue_free()
	crowd.clear()
	var parent_node: Node = gameplay_world.get_node_or_null("Enemies") if gameplay_world else null
	if not parent_node: parent_node = gameplay_world if gameplay_world else (world_node if world_node else self)
	var count := [1, 9, 29][crowd_mode] as int
	for i in count:
		var npc := CHARACTER.instantiate() as MudCharacter
		npc.player_controlled = false
		npc.position = Vector2(60.0 + (i % 15) * 45.0, MAIN_SURFACE_Y - 2.0)
		parent_node.add_child(npc)
		npc.rig.time = i * 0.31
		npc.rig.gait.phase = fposmod(i * 0.31, 1.0)
		npc.body_renderer.mud_color = Color.from_hsv(0.18 + i * 0.005, 0.42, 0.45 + (i % 3) * 0.08)
		npc.weapons.equip(null)
		npc.equipment.toggle()
		crowd.append(npc)

func spawn_real_enemy() -> MudCharacter:
	var game := get_node_or_null("/root/Game")
	var enemy := CHARACTER.instantiate() as MudCharacter
	enemy.name = "TrainingEnemy_%02d" % (real_enemies.size() + 1)
	enemy.player_controlled = false
	enemy.score_profile = preload("res://resources/grunt_score.tres")
	enemy.score_credit_enabled = true
	enemy.max_health = 45.0
	var desired_x := player.position.x + player.facing * 140.0
	enemy.position = Vector2(desired_x, MAIN_SURFACE_Y - 2.0)
	var parent_node: Node = gameplay_world.get_node_or_null("Enemies") if gameplay_world else null
	if not parent_node: parent_node = gameplay_world if gameplay_world else (world_node if world_node else self)
	parent_node.add_child(enemy)
	enemy.body_renderer.mud_color = Color("87505a")
	enemy.add_to_group(&"training_enemy")
	if game and is_instance_valid(game.current_session) and is_instance_valid(game.current_session.combat_context):
		game.current_session.combat_context.register_actor(enemy)
		enemy.tree_exiting.connect(func() -> void:
			if is_instance_valid(game.current_session) and is_instance_valid(game.current_session.combat_context):
				game.current_session.combat_context.unregister_actor(enemy)
		)
	var controller: Node = ENEMY_CONTROLLER.new()
	controller.name = "EnemyController"
	controller.actor = enemy
	controller.target = player
	enemy.add_child(controller)
	real_enemies.append(enemy)
	return enemy

func spawn_score_target() -> void:
	if is_instance_valid(scoring_enemy): scoring_enemy.queue_free()
	scoring_enemy = CHARACTER.instantiate()
	scoring_enemy.player_controlled = false
	scoring_enemy.score_profile = preload("res://resources/grunt_score.tres")
	scoring_enemy.max_health = 30.0
	var spawn_x := clampf(player.position.x + player.facing * 65.0, 40.0, 840.0)
	scoring_enemy.position = Vector2(spawn_x, player.position.y)
	var parent_node: Node = gameplay_world.get_node_or_null("Enemies") if gameplay_world else null
	if not parent_node: parent_node = gameplay_world if gameplay_world else (world_node if world_node else self)
	parent_node.add_child(scoring_enemy)
	scoring_enemy.body_renderer.mud_color = Color("875f60")
	scoring_enemy.weapons.equip(null)

func _draw() -> void:
	# World-space measurement lines and markers
	_draw_zone_markers()

func _draw_zone_markers() -> void:
	var font_res := font if font else ThemeDB.fallback_font
	
	# =========================================================================
	# ZONE 01: Baseline vertical floor markers
	# =========================================================================
	for x in range(0, 801, 32):
		var is_strong := (x % 128 == 0)
		var tick_h := 14.0 if is_strong else 6.0
		var col := Color("e4e7eb") if is_strong else Color("8b939c", 0.7)
		draw_line(Vector2(x, MAIN_SURFACE_Y), Vector2(x, MAIN_SURFACE_Y + tick_h), col, 1.0)
		if is_strong:
			draw_string(font_res, Vector2(x - 10, MAIN_SURFACE_Y + 24), str(x), HORIZONTAL_ALIGNMENT_CENTER, 20, 8, Color("e4e7eb"))
	
	# Facing Symmetry Station at X = 400
	draw_line(Vector2(400, MAIN_SURFACE_Y - 50), Vector2(400, MAIN_SURFACE_Y), Color("e4e7eb"), 1.5)
	draw_string(font_res, Vector2(300, MAIN_SURFACE_Y - 54), "LEFT TEST ← │ → RIGHT TEST", HORIZONTAL_ALIGNMENT_CENTER, 200, 9, Color("ffffff"))
	var sym_offsets: Array[int] = [-192, -128, -64, 0, 64, 128, 192]
	for off in sym_offsets:
		var sx: float = 400.0 + off
		draw_line(Vector2(sx, MAIN_SURFACE_Y - 8), Vector2(sx, MAIN_SURFACE_Y), Color("d49b3d"), 1.0)
		draw_string(font_res, Vector2(sx - 16, MAIN_SURFACE_Y - 12), "%+d" % off if off != 0 else "0", HORIZONTAL_ALIGNMENT_CENTER, 32, 7, Color("d49b3d"))
	
	# =========================================================================
	# ZONE 02: Coyote Steps timing reference markers
	# =========================================================================
	var ledges: Array[Dictionary] = [
		{"x": 980.0, "y": 64.0, "label": "LEDGE A: WALK"},
		{"x": 1200.0, "y": 64.0, "label": "LEDGE B: RUN"},
		{"x": 1380.0, "y": 64.0, "label": "LEDGE C: ATK"},
	]
	for l in ledges:
		var lx: float = l["x"]
		var ly: float = l["y"]
		draw_string(font_res, Vector2(lx - 80, ly - 8), l["label"], HORIZONTAL_ALIGNMENT_LEFT, 100, 8, Color("d49b3d"))
		# Timing ticks below edge (0.05s, 0.10s base, 0.14s pardon, 0.16s wile, 0.20s max)
		var ticks: Array[Dictionary] = [
			{"t": 0.05, "dy": 8.0, "text": "0.05s"},
			{"t": 0.10, "dy": 20.0, "text": "0.10s (BASE)"},
			{"t": 0.14, "dy": 36.0, "text": "0.14s"},
			{"t": 0.16, "dy": 48.0, "text": "0.16s (WILE)"},
			{"t": 0.20, "dy": 68.0, "text": "0.20s (MAX)"},
		]
		for tk in ticks:
			var ty: float = ly + tk["dy"]
			draw_line(Vector2(lx, ty), Vector2(lx + 12, ty), Color("d49b3d", 0.8), 1.0)
			draw_string(font_res, Vector2(lx + 16, ty + 3), tk["text"], HORIZONTAL_ALIGNMENT_LEFT, 70, 7, Color("d49b3d"))
	
	# =========================================================================
	# ZONE 06: Gravity Drop Shaft vertical measurement wall
	# =========================================================================
	draw_string(font_res, Vector2(1420, -56), "ZONE 06: GRAVITY SHAFT (g x 0.65)", HORIZONTAL_ALIGNMENT_LEFT, 160, 8, Color("d4dae0"))
	for y_off in range(16, 209, 16):
		var gy: float = -48.0 + y_off
		var is_major := (y_off % 32 == 0)
		var tick_w := 14.0 if is_major else 6.0
		draw_line(Vector2(1500, gy), Vector2(1500 + tick_w, gy), Color("e4e7eb"), 1.0)
		if is_major:
			draw_string(font_res, Vector2(1518, gy + 3), "%d px" % y_off, HORIZONTAL_ALIGNMENT_LEFT, 40, 7, Color("e4e7eb"))
	
	# =========================================================================
	# ZONE 03: Gap Calibration labels
	# =========================================================================
	var gap_labels: Array[Dictionary] = [
		{"x": 1684.0, "w": "48 px"},
		{"x": 1804.0, "w": "64 px"},
		{"x": 1940.0, "w": "80 px"},
		{"x": 2092.0, "w": "96 px"},
		{"x": 2260.0, "w": "112 px"},
		{"x": 2444.0, "w": "128 px"},
		{"x": 2652.0, "w": "160 px"},
	]
	for g in gap_labels:
		draw_string(font_res, Vector2(g["x"] - 20, 160), "GAP " + g["w"], HORIZONTAL_ALIGNMENT_CENTER, 60, 7, Color("d4dae0"))
	
	# =========================================================================
	# ZONE 05: Height Calibration Vertical Wall
	# =========================================================================
	draw_string(font_res, Vector2(2860, -56), "ZONE 05: VERTICAL APEX RULER", HORIZONTAL_ALIGNMENT_LEFT, 160, 8, Color("d4dae0"))
	for h in range(16, 209, 16):
		var hy: float = MAIN_SURFACE_Y - h
		var is_major := (h % 32 == 0)
		var tw := 12.0 if is_major else 5.0
		draw_line(Vector2(2910 - tw, hy), Vector2(2910, hy), Color("e4e7eb"), 1.0)
		if is_major:
			draw_string(font_res, Vector2(2870, hy + 3), "%d" % h, HORIZONTAL_ALIGNMENT_RIGHT, 34, 7, Color("e4e7eb"))
	
	# =========================================================================
	# ZONE 07: Wall Tower status label
	# =========================================================================
	draw_string(font_res, Vector2(3390, -112), "ZONE 07: WALL MECHANICS TOWER", HORIZONTAL_ALIGNMENT_LEFT, 180, 8, Color("4e9fa8"))
	
	# =========================================================================
	# ZONE 08: Combat Centerline
	# =========================================================================
	draw_line(Vector2(3980, MAIN_SURFACE_Y - 60), Vector2(3980, MAIN_SURFACE_Y), Color("8b6fb5"), 1.0)
	draw_string(font_res, Vector2(3910, MAIN_SURFACE_Y - 66), "COMBAT SYMMETRY LINE", HORIZONTAL_ALIGNMENT_CENTER, 140, 8, Color("8b6fb5"))

func _on_tactical_overlay_draw() -> void:
	if not font or not is_instance_valid(player): return
	
	# Top status header
	tactical_overlay.draw_rect(Rect2(0, 0, 640, 42), Color(0.04, 0.07, 0.09, 0.90))
	tactical_overlay.draw_rect(Rect2(12, 10, 3, 22), Color("c1d18b"))
	tactical_overlay.draw_string(font, Vector2(22, 22), "CONTRA-AVALOKITA // DETERMINISTIC MECHANICS LABORATORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e0e7cc"))
	tactical_overlay.draw_string(font, Vector2(22, 35), "FLAT-COLOR RIG TESTBED // COYOTE & MODIFIER VERIFICATION // GODOT 4.7", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("81947e"))
	tactical_overlay.draw_string(font, Vector2(510, 22), "%3d FPS" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_RIGHT, -1, 9, Color("bfd08c"))
	
	# Notice toast
	if pickup_notice_left > 0.0:
		tactical_overlay.draw_rect(Rect2(120, 46, 400, 22), Color(0.04, 0.08, 0.09, 0.94))
		tactical_overlay.draw_rect(Rect2(120, 46, 400, 22), Color("c1d18b"), false, 1.0)
		tactical_overlay.draw_string(font, Vector2(124, 61), pickup_notice, HORIZONTAL_ALIGNMENT_CENTER, 392, 8, Color("e6f0cf"))
	elif knockback_feedback_left > 0.0:
		tactical_overlay.draw_rect(Rect2(120, 46, 400, 22), Color(0.12, 0.04, 0.04, 0.94))
		tactical_overlay.draw_rect(Rect2(120, 46, 400, 22), Color("c85050"), false, 1.0)
		tactical_overlay.draw_string(font, Vector2(124, 61), knockback_feedback, HORIZONTAL_ALIGNMENT_CENTER, 392, 8, Color("ffc0c0"))
	
	# 1. Live Effective Stats Panel (Top-Left)
	if show_stats_panel:
		_draw_live_stats_panel()
	
	# 2. In-World Floating UNFALLEN Indicator
	_draw_unfallen_indicator()
	
	# Bottom control bar
	tactical_overlay.draw_rect(Rect2(0, 324, 640, 36), Color(0.04, 0.07, 0.09, 0.94))
	tactical_overlay.draw_line(Vector2(0, 324), Vector2(640, 324), Color("293a3b"), 1.0)
	tactical_overlay.draw_string(font, Vector2(14, 338), "1-6 TELEPORT ZONES  |  7-9 KNOCKBACK (W/M/H)  |  R RESPAWN  |  K DIE  |  F1 STATS  |  F2 ITEMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("d1d9b7"))
	tactical_overlay.draw_string(font, Vector2(14, 352), "A/D MOVE  |  SHIFT RUN  |  SPACE JUMP  |  J ATTACK  |  L BLOCK  |  F6 ITEM CARDS  |  C SHAKE [%s]" % ("ON" if camera_shake_enabled else "OFF"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("81947e"))

func _draw_live_stats_panel() -> void:
	var assist := player.movement_assist
	var panel := Rect2(12, 48, 172, 196)
	tactical_overlay.draw_rect(panel, Color(0.04, 0.07, 0.09, 0.88))
	tactical_overlay.draw_rect(panel, Color("293a3b"), false, 1.0)
	tactical_overlay.draw_string(font, Vector2(18, 62), "LIVE TELEMETRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("c1d18b"))
	
	var facing_str := "RIGHT" if player.facing > 0.0 else "LEFT"
	var grounded_str := "TRUE" if player.is_on_floor() else "FALSE"
	var unfallen_str := "TRUE" if assist.is_unfallen() else "FALSE"
	var grav_mult := assist.get_gravity_multiplier()
	var jump_src := String(assist.source_name())
	
	var stats: Array[String] = [
		"Facing             " + facing_str,
		"State              " + String(player.state),
		"Grounded           " + grounded_str,
		"Velocity           %4.0f, %4.0f" % [player.velocity.x, player.velocity.y],
		"",
		"Coyote Base        %.3f s" % assist.base_coyote_time,
		"Coyote Bonus       %+.3f s" % assist.coyote_time_bonus,
		"Coyote Effective   %.3f s" % assist.get_effective_coyote_time(),
		"Coyote Remaining   %.3f s" % assist.get_coyote_remaining(),
		"UNFALLEN           " + unfallen_str,
		"",
		"Jump Buffer        %.3f / %.3f" % [assist.jump_buffer_remaining, assist.get_effective_jump_buffer_time()],
		"Gravity Multiplier %.2f" % grav_mult,
		"Last Jump Source   " + jump_src,
		"Active Items       %d / %d" % [player.item_inventory.items().size(), COYOTE_ITEMS.size()],
	]
	
	for i in stats.size():
		if stats[i] == "": continue
		var col := Color("e0e7cc")
		if stats[i].begins_with("UNFALLEN") and assist.is_unfallen():
			col = Color("d49b3d")
		elif stats[i].begins_with("Gravity Multiplier") and grav_mult < 0.99:
			col = Color("62c7d4")
		tactical_overlay.draw_string(font, Vector2(18, 76 + i * 11), stats[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, col)

func _draw_unfallen_indicator() -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera): return
	var assist := player.movement_assist
	
	# Determine state badge
	var badge_text := "GROUND"
	var badge_col := Color("6b7c76")
	if assist.is_unfallen():
		badge_text = "UNFALLEN"
		badge_col = Color("d49b3d")
	elif player.is_wall_attached():
		badge_text = "WALL"
		badge_col = Color("4e9fa8")
	elif not player.is_on_floor():
		badge_text = "AIRBORNE"
		badge_col = Color("7088a0")
	
	# Screen space position above player
	var screen_pos := player.global_position - camera.get_screen_center_position() + Vector2(320, 180)
	var badge_rect := Rect2(screen_pos.x - 36, screen_pos.y - 74, 72, 14)
	tactical_overlay.draw_rect(badge_rect, Color(0.04, 0.07, 0.09, 0.85))
	tactical_overlay.draw_rect(badge_rect, badge_col, false, 1.0)
	tactical_overlay.draw_string(font, Vector2(screen_pos.x - 34, screen_pos.y - 63), badge_text, HORIZONTAL_ALIGNMENT_CENTER, 68, 8, badge_col)
	
	# If UNFALLEN is active, draw shrinking progress bar
	if assist.is_unfallen():
		var prog := assist.get_coyote_progress()
		var bar_rect := Rect2(screen_pos.x - 36, screen_pos.y - 58, 72, 5)
		tactical_overlay.draw_rect(bar_rect, Color("1a1f24"))
		tactical_overlay.draw_rect(Rect2(screen_pos.x - 36, screen_pos.y - 58, 72 * prog, 5), Color("d49b3d"))
		tactical_overlay.draw_string(font, Vector2(screen_pos.x - 34, screen_pos.y - 50), "%.3f / %.3f" % [assist.coyote_remaining, assist.get_effective_coyote_time()], HORIZONTAL_ALIGNMENT_CENTER, 68, 7, Color("ffffff"))
	elif assist.jump_buffer_remaining > 0.0:
		var buf_prog := assist.jump_buffer_remaining / maxf(assist.get_effective_jump_buffer_time(), 0.001)
		var buf_rect := Rect2(screen_pos.x - 36, screen_pos.y - 58, 72, 4)
		tactical_overlay.draw_rect(buf_rect, Color("1a1f24"))
		tactical_overlay.draw_rect(Rect2(screen_pos.x - 36, screen_pos.y - 58, 72 * buf_prog, 4), Color("62c7d4"))
