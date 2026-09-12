extends Node2D

const CHARACTER := preload("res://scenes/mud_character.tscn")
const DUMMY := preload("res://scripts/training_dummy.gd")
const Glyphs := preload("res://scripts/six_realm_glyphs.gd")
const MAIN_DECK_SURFACE_Y := 138.0
const HELIPAD_SURFACE_Y := 124.0

var world_node: Node2D
var background_node: Node2D
var geometry_node: Node2D
var hud_layer: CanvasLayer
var tactical_overlay: Control
var camera: Camera2D

var player: MudCharacter
var scoring_enemy: MudCharacter
var dummy: Node2D
var crowd: Array[MudCharacter] = []
var crowd_mode := 0
var details_menu_open := false
var elapsed := 0.0
var frame := 0
var font: Font

@export var camera_shake_enabled := false
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
	bind("toggle_details", [KEY_F5])
	bind("crowd", [KEY_T])
	bind("reset", [KEY_R])
	bind("kill", [KEY_K])
	bind("score_target", [KEY_F3])
	bind("score_realm", [KEY_F4])
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf")

	# 1. World Hierarchy
	world_node = Node2D.new()
	world_node.name = "World"
	add_child(world_node)

	# 1.1 Backgrounds (Origin (0,0), uncentered, exact 870x288)
	background_node = Node2D.new()
	background_node.name = "Background"
	world_node.add_child(background_node)

	var sky_sprite := Sprite2D.new()
	sky_sprite.name = "SkySea"
	sky_sprite.texture = preload("res://assets/backgrounds/oil_rig_sky_sea.png")
	sky_sprite.centered = false
	sky_sprite.position = Vector2.ZERO
	sky_sprite.z_index = -20
	background_node.add_child(sky_sprite)

	var rig_sprite := Sprite2D.new()
	rig_sprite.name = "Platform"
	rig_sprite.texture = preload("res://assets/backgrounds/oil_rig_platform.png")
	rig_sprite.centered = false
	rig_sprite.position = Vector2.ZERO
	rig_sprite.z_index = -10
	background_node.add_child(rig_sprite)

	# 1.2 Geometry & Collision Decks
	geometry_node = Node2D.new()
	geometry_node.name = "Geometry"
	world_node.add_child(geometry_node)

	# Main deck: Surface Y = 138, extends downwards
	# Center = ((32 + 868)/2, 138 + 20/2) = (450, 148)
	var main_deck_size := Vector2(836, 20)
	var main_deck_center := Vector2(450, MAIN_DECK_SURFACE_Y + main_deck_size.y * 0.5)
	platform(main_deck_center, main_deck_size)

	# Helipad deck: Surface Y = 124, extends downwards
	# Center = ((780 + 865)/2, 124 + 16/2) = (822.5, 132)
	var helipad_size := Vector2(85, 16)
	var helipad_center := Vector2(822.5, HELIPAD_SURFACE_Y + helipad_size.y * 0.5)
	platform(helipad_center, helipad_size)

	# Safety / Test platform at Y = 284 for compatibility with legacy test vectors
	platform(Vector2(435, 303), Vector2(900, 38))

	# Boundaries (walls at X=16 and X=878)
	platform(Vector2(16, 144), Vector2(16, 288))
	platform(Vector2(878, 144), Vector2(16, 288))

	# 1.3 Characters & Targets
	player = CHARACTER.instantiate()
	player.name = "Player"
	# Character collision capsule bottom is at position.y + 2.0 -> Y=136 rests at surface Y=138
	player.position = Vector2(250, MAIN_DECK_SURFACE_Y - 2.0)
	world_node.add_child(player)

	dummy = Node2D.new()
	dummy.name = "Dummy"
	dummy.set_script(DUMMY)
	dummy.position = Vector2(411, MAIN_DECK_SURFACE_Y - 2.0)
	world_node.add_child(dummy)

	var npc := CHARACTER.instantiate() as MudCharacter
	npc.name = "NPC"
	npc.player_controlled = false
	npc.position = Vector2(130, MAIN_DECK_SURFACE_Y - 2.0)
	world_node.add_child(npc)
	npc.body_renderer.mud_color = Color("87704b")
	npc.weapons.equip(null)
	npc.equipment.toggle()
	npc.rig.time = 1.8
	crowd.append(npc)

	# 2. Camera2D with 1.25x Zoom and Integer Pixel Tracking
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.25, 1.25)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 870
	camera.limit_bottom = 288
	camera.position_smoothing_enabled = false
	var init_x := clampf(player.position.x, 256.0, 614.0)
	camera.position = Vector2(round(init_x), 144.0)
	add_child(camera)

	# 3. Screen-Space Tactical HUD (CanvasLayer)
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	hud_layer.layer = 5
	add_child(hud_layer)

	tactical_overlay = Control.new()
	tactical_overlay.name = "TacticalOverlay"
	tactical_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tactical_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	tactical_overlay.draw.connect(_on_tactical_hud_draw)
	hud_layer.add_child(tactical_overlay)

func platform(center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	if geometry_node:
		geometry_node.add_child(body)
	else:
		add_child(body)
	return body

func spawn_score_target() -> void:
	if is_instance_valid(scoring_enemy): scoring_enemy.queue_free()
	scoring_enemy = CHARACTER.instantiate()
	scoring_enemy.player_controlled = false
	scoring_enemy.score_profile = preload("res://resources/grunt_score.tres")
	scoring_enemy.max_health = 30
	var spawn_x := clampf(player.position.x + player.facing * 65.0, 40.0, 840.0)
	scoring_enemy.position = Vector2(spawn_x, player.position.y)
	world_node.add_child(scoring_enemy)
	scoring_enemy.body_renderer.mud_color = Color("875f60")
	scoring_enemy.weapons.equip(null)

func cycle_crowd() -> void:
	crowd_mode = (crowd_mode + 1) % 3
	for npc in crowd:
		if is_instance_valid(npc): npc.queue_free()
	crowd.clear()
	var count := [1, 9, 29][crowd_mode] as int
	for i in count:
		var npc := CHARACTER.instantiate() as MudCharacter
		npc.player_controlled = false
		npc.position = Vector2(60.0 + (i % 15) * 45.0, MAIN_DECK_SURFACE_Y - 2.0)
		world_node.add_child(npc)
		npc.rig.time = i * 0.31
		npc.rig.gait.phase = fposmod(i * 0.31, 1.0)
		npc.body_renderer.mud_color = Color.from_hsv(0.18 + i * 0.005, 0.42, 0.45 + (i % 3) * 0.08)
		npc.weapons.equip(null)
		npc.equipment.toggle()
		crowd.append(npc)

func trigger_camera_shake(dir: Vector2, amp: float, duration: float = 0.08) -> void:
	if not camera_shake_enabled:
		camera_shake_offset = Vector2.ZERO
		if camera: camera.offset = Vector2.ZERO
		return
	camera_shake_dir = dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	camera_shake_amp = amp
	camera_shake_duration = maxf(duration, 0.001)
	camera_shake_timer = camera_shake_duration
	camera_shake_offset = (camera_shake_dir * amp).round()
	if camera: camera.offset = camera_shake_offset

func _process(delta: float) -> void:
	elapsed += delta
	frame += 1

	# Camera integer pixel tracking
	if is_instance_valid(player) and is_instance_valid(camera):
		var target_x := clampf(player.global_position.x, 256.0, 614.0)
		camera.global_position.x = round(
			lerpf(camera.global_position.x, target_x, 1.0 - exp(-8.0 * delta))
		)
		camera.global_position.y = 144.0

		if camera_shake_enabled and camera_shake_timer > 0.0:
			camera_shake_timer = maxf(0.0, camera_shake_timer - delta)
			var p: float = camera_shake_timer / camera_shake_duration
			var offset_val: float = cos((camera_shake_duration - camera_shake_timer) * 55.0) * camera_shake_amp * p
			camera_shake_offset = (camera_shake_dir * offset_val).round()
			camera.offset = camera_shake_offset
		else:
			camera_shake_offset = Vector2.ZERO
			camera.offset = Vector2.ZERO

	if not is_instance_valid(player): return

	# Controls & shortcuts
	if Input.is_action_just_pressed("toggle_details"):
		details_menu_open = not details_menu_open
	if Input.is_action_just_pressed("score_target"): spawn_score_target()
	if Input.is_action_just_pressed("score_realm"):
		var ks := _get_score_system()
		if ks: ks.realm = (ks.realm + 1) % 6
	if Input.is_action_just_pressed("crowd"): cycle_crowd()
	if Input.is_action_just_pressed("kill"):
		player.die()
	if player.state == &"Dead" and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack")):
		player.rise()
	if Input.is_action_just_pressed("reset"):
		player.position = Vector2(250, MAIN_DECK_SURFACE_Y - 2.0)
		player.velocity = Vector2.ZERO
		player.revive()

	for i in crowd.size():
		var npc := crowd[i]
		if is_instance_valid(npc) and crowd_mode > 0:
			npc.set_intent(sin(elapsed * 0.7 + i) * 0.25, false, fmod(elapsed + i * 0.2, 2.1) < delta)

	if is_instance_valid(tactical_overlay):
		tactical_overlay.queue_redraw()

	if "--capture" in OS.get_cmdline_user_args() and frame == 80:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/mvp_preview.png")
		get_tree().quit()

func _on_tactical_hud_draw() -> void:
	if not font or not is_instance_valid(player): return

	# Top status header
	tactical_overlay.draw_rect(Rect2(0, 0, 640, 48), Color(0.04, 0.07, 0.09, 0.88))
	tactical_overlay.draw_rect(Rect2(16, 12, 3, 24), Color("c1d18b"))
	tactical_overlay.draw_string(font, Vector2(26, 25), "MIRE / MOTION LAB // RIG 07 OFFSHORE SECTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e0e7cc"))
	tactical_overlay.draw_string(font, Vector2(26, 40), "PROCEDURAL HUMANOID // FLOAT RIG + SDF BODY // GODOT 4.7", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("81947e"))
	tactical_overlay.draw_string(font, Vector2(490, 24), "%02d ACTORS   %3d FPS" % [crowd.size() + 1, Engine.get_frames_per_second()], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("bfd08c"))
	tactical_overlay.draw_string(font, Vector2(490, 39), "T  POPULATION: 2 / 10 / 30", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("a3b5af"))

	# Live telemetry card (screen coordinates) - hidden when details modal is open
	if not details_menu_open:
		tactical_overlay.draw_rect(Rect2(480, 56, 146, 130), Color(0.05, 0.09, 0.11, 0.85))
		tactical_overlay.draw_rect(Rect2(480, 56, 146, 130), Color("293a3b"), false, 1.0)
		tactical_overlay.draw_string(font, Vector2(488, 72), "LIVE TELEMETRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("c3d29a"))

		var weapon_name := player.weapons.current.weapon_name if player.weapons.current else "Unarmed"
		var lines: Array[String] = [
			"STATE    " + String(player.state),
			"ACTION   " + String(player.action_state),
			"VEL      %5.1f / %5.1f" % [player.velocity.x, player.velocity.y],
			"GROUNDED " + str(player.is_on_floor()),
			"ELBOW    %3.0f deg" % player.rig.angles.get("ArmFront", 0),
			"KNEE     %3.0f deg" % player.rig.angles.get("LegFront", 0),
			"WEAPON   " + weapon_name,
			"DUMMY    %02d HITS" % dummy.hit_count
		]
		for i in lines.size():
			tactical_overlay.draw_string(font, Vector2(488, 87 + i * 12), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("a3b5af"))

	# Debug joint rig telemetry bar if F1 toggled
	if player.rig.debug_draw:
		var gait_phase := player.anim_player.current_animation_position / maxf(player.anim_player.current_animation_length, .001)
		var action_phase := player.attack_time / maxf(player.attack_duration, .001) if player.is_attacking() else 0.0
		tactical_overlay.draw_rect(Rect2(16, 56, 380, 44), Color(0.05, 0.09, 0.11, 0.85))
		tactical_overlay.draw_string(font, Vector2(22, 70), "MOVE %s  ACT %s  GAIT %.2f  ATK %.2f" % [player.state, player.action_state, gait_phase, action_phase], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e0e7cc"))
		tactical_overlay.draw_string(font, Vector2(22, 83), "FLOOR %s  VY %.1f   GREEN: BASE  PINK: ACTION  GOLD: PELVIS" % [str(player.is_on_floor()), player.velocity.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("81947e"))
		# Wall & Spine deformation debug row
		var spine_w := player.pose_composer.spine_controller.spine_wall_weight if (player.pose_composer and player.pose_composer.spine_controller) else 0.0
		if player.is_wall_attached() or player.wall_action != &"None" or spine_w > 0.01:
			tactical_overlay.draw_string(font, Vector2(22, 96),
				"WALL %s  SPINE_WEIGHT %.2f  ACTION %s  SIDE %+.0f" % [
					String(player.wall_action), spine_w, String(player.action_state), player.wall_side
				], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("ffd467"))
		# Draw Spine deformation chain: Pelvis (white) -> SpineLower (yellow) -> SpineUpper (orange) -> Chest (cyan)
		var skeleton: Skeleton2D = player.skeleton
		if skeleton:
			var cam_offset := Vector2.ZERO
			if has_node("Camera2D"): cam_offset = get_node("Camera2D").get_screen_center_position() - Vector2(320, 180)
			var b_pelvis := skeleton.get_node_or_null("Pelvis") as Bone2D
			var b_torso := skeleton.get_node_or_null("Pelvis/Torso") as Bone2D
			var b_spinel := player._spine_lower_bone
			var b_spineu := player._spine_upper_bone
			if b_pelvis and b_torso:
				var p_pos := b_pelvis.global_position - cam_offset
				var c_pos := b_torso.global_position - cam_offset
				var sl_pos := b_spinel.global_position - cam_offset if b_spinel else p_pos.lerp(c_pos, 0.33)
				var su_pos := b_spineu.global_position - cam_offset if b_spineu else p_pos.lerp(c_pos, 0.67)
				tactical_overlay.draw_circle(p_pos, 3.0, Color("ffffff"))   # Pelvis = white
				tactical_overlay.draw_circle(sl_pos, 2.5, Color("ffd467")) # SpineLower = yellow
				tactical_overlay.draw_circle(su_pos, 2.5, Color("ff8c32")) # SpineUpper = orange
				tactical_overlay.draw_circle(c_pos, 3.0, Color("7affff"))   # Chest = cyan
				tactical_overlay.draw_line(p_pos, sl_pos, Color("ffffff", 0.7), 1.5)
				tactical_overlay.draw_line(sl_pos, su_pos, Color("ffd467", 0.7), 1.5)
				tactical_overlay.draw_line(su_pos, c_pos, Color("7affff", 0.7), 1.5)


	# Bottom control bar
	tactical_overlay.draw_rect(Rect2(0, 324, 640, 36), Color(0.04, 0.07, 0.09, 0.92))
	tactical_overlay.draw_line(Vector2(0, 324), Vector2(640, 324), Color("293a3b"), 1.0)
	tactical_overlay.draw_string(font, Vector2(18, 339), "A D  WALK    HOLD SHIFT  RUN    SPACE  JUMP    J / LMB  ATTACK    L  BLOCK    E  ARMOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d1d9b7"))
	tactical_overlay.draw_string(font, Vector2(18, 353), "1  SWORD    2  UNARMED    F1  JOINTS + MORPHS    F5  DETAILS    K  DIE    SPACE  RISE    R  RESET    T  CROWD", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("81947e"))

	# F5 Details Panel Menu Modal
	if details_menu_open:
		_draw_details_menu()

func _draw_details_menu() -> void:
	# 1. Dimmed backdrop
	tactical_overlay.draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.04, 0.06, 0.78))

	# 2. Outer Frame (460 x 248)
	var panel := Rect2(90, 56, 460, 248)
	tactical_overlay.draw_rect(panel, Color("0a141a"))
	tactical_overlay.draw_rect(panel, Color("293a3b"), false, 1.0)

	# Header bar
	tactical_overlay.draw_rect(Rect2(90, 56, 460, 26), Color("132329"))
	tactical_overlay.draw_line(Vector2(90, 82), Vector2(550, 82), Color("293a3b"), 1.0)
	tactical_overlay.draw_rect(Rect2(98, 63, 3, 12), Color("c1d18b"))
	tactical_overlay.draw_string(font, Vector2(108, 73), "TACTICAL EVALUATION & SCORING // 战术评估详情面板", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e0e7cc"))
	tactical_overlay.draw_string(font, Vector2(462, 73), "[F5] 关闭 / CLOSE", HORIZONTAL_ALIGNMENT_RIGHT, -1, 9, Color("81947e"))

	# 3. Left Box: 击杀得分与六道系统 (KILL SCORING & SIX REALMS)
	var box_l := Rect2(104, 92, 210, 200)
	tactical_overlay.draw_rect(box_l, Color(0.05, 0.09, 0.12, 0.75))
	tactical_overlay.draw_rect(box_l, Color("1d2e33"), false, 1.0)
	tactical_overlay.draw_rect(Rect2(104, 92, 210, 20), Color(0.08, 0.14, 0.18, 0.85))
	tactical_overlay.draw_string(font, Vector2(112, 106), "击杀得分 / 六进制六道", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("c3d29a"))

	var ks := _get_score_system()
	var total_score: int = ks.total if ks else 0
	var streak: int = ks.streak if ks else 0
	var realm_idx: int = clampi(ks.realm if ks else 0, 0, 5)

	# Heximal glyphs display
	tactical_overlay.draw_string(font, Vector2(112, 126), "六进制总分:", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("a3b5af"))
	var digits := Glyphs.digits(total_score)
	for i in digits.size():
		tactical_overlay.draw_set_transform(Vector2(174 + i * 16.0, 123), 0, Vector2.ONE * 0.65)
		Glyphs.draw_symbol(tactical_overlay, digits[i], Color("ffffff"), 1.1)
	tactical_overlay.draw_set_transform(Vector2.ZERO)

	tactical_overlay.draw_string(font, Vector2(112, 148), "十进制换算:  %d PT" % total_score, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("e0e7cc"))

	# Current Realm
	var realm_name: String = Glyphs.NAMES_ZH[realm_idx]
	tactical_overlay.draw_string(font, Vector2(112, 170), "当前道相:  %s" % realm_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("a3b5af"))
	tactical_overlay.draw_set_transform(Vector2(208, 166), 0, Vector2.ONE * 0.55)
	Glyphs.draw_symbol(tactical_overlay, realm_idx, Color("c1d18b"), 1.0)
	tactical_overlay.draw_set_transform(Vector2.ZERO)

	# Streak / combo
	tactical_overlay.draw_string(font, Vector2(112, 192), "当前连杀:  %d 连杀" % streak, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("a3b5af"))
	if ks and streak > 0:
		var rem_time := maxf(0.0, ks.combo_timeout - (ks.clock - ks.last_kill))
		tactical_overlay.draw_string(font, Vector2(112, 208), "连击剩余:  %.1f 秒" % rem_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("81947e"))
	else:
		tactical_overlay.draw_string(font, Vector2(112, 208), "连击状态:  空闲 / IDLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("6b7c76"))

	# Shortcuts hint box inside left panel
	tactical_overlay.draw_rect(Rect2(110, 226, 198, 56), Color(0.03, 0.06, 0.08, 0.7))
	tactical_overlay.draw_rect(Rect2(110, 226, 198, 56), Color("1a292e"), false, 1.0)
	tactical_overlay.draw_string(font, Vector2(116, 243), "[F3] 召唤评分目标", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("bfd08c"))
	tactical_overlay.draw_string(font, Vector2(116, 258), "[F4] 切换六道道相", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("bfd08c"))
	tactical_overlay.draw_string(font, Vector2(116, 273), "击杀评分仅在目标死亡时结算", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("6b7c76"))

	# 4. Right Box: 机体战术遥测 (UNIT & COMBAT TELEMETRY)
	var box_r := Rect2(326, 92, 210, 200)
	tactical_overlay.draw_rect(box_r, Color(0.05, 0.09, 0.12, 0.75))
	tactical_overlay.draw_rect(box_r, Color("1d2e33"), false, 1.0)
	tactical_overlay.draw_rect(Rect2(326, 92, 210, 20), Color(0.08, 0.14, 0.18, 0.85))
	tactical_overlay.draw_string(font, Vector2(334, 106), "机体状态与关节遥测", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("c3d29a"))

	var weapon_name := player.weapons.current.weapon_name if player.weapons.current else "Unarmed"
	var r_lines: Array[String] = [
		"生命值 (HP)   %3.0f / %3.0f" % [player.health, player.max_health],
		"架势值 (POISE)  %3.0f / %3.0f" % [player.stability, player.max_stability],
		"移动状态       " + String(player.state),
		"动作层         " + String(player.action_state),
		"速度 (VEL)     vx=%.1f vy=%.1f" % [player.velocity.x, player.velocity.y],
		"肘弯曲/压迫    %3.0f° / %.2f" % [player.rig.angles.get("ArmFront", 0), player.rig.compressions.get("ArmFront", 0)],
		"膝关节弯曲     %3.0f°" % player.rig.angles.get("LegFront", 0),
		"当前武装       " + weapon_name,
		"训练木桩命中   %02d 次" % dummy.hit_count
	]
	for i in r_lines.size():
		tactical_overlay.draw_string(font, Vector2(334, 126 + i * 18), r_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("a3b5af"))
