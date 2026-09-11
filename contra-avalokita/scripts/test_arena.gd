extends Node2D
const CHARACTER := preload("res://scenes/mud_character.tscn")
const DUMMY := preload("res://scripts/training_dummy.gd")
var player: MudCharacter
var dummy: Node2D
var crowd: Array[MudCharacter] = []
var crowd_mode := 0
var elapsed := 0.0
var frame := 0
var font: Font

func _enter_tree() -> void:
	bind("move_left", [KEY_A, KEY_LEFT])
	bind("move_right", [KEY_D, KEY_RIGHT])
	bind("jump", [KEY_SPACE])
	bind("walk", [KEY_SHIFT])
	bind("attack", [KEY_J])
	bind("equipment", [KEY_E])
	bind("weapon_sword", [KEY_1])
	bind("weapon_none", [KEY_2])
	bind("debug_rig", [KEY_F1])
	bind("crowd", [KEY_T])
	bind("reset", [KEY_R])
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

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = ThemeDB.fallback_font
	platform(Vector2(320, 303), Vector2(640, 38))
	platform(Vector2(-8, 160), Vector2(16, 320))
	platform(Vector2(648, 160), Vector2(16, 320))
	player = CHARACTER.instantiate()
	player.position = Vector2(285, 281)
	add_child(player)
	dummy = Node2D.new()
	dummy.set_script(DUMMY)
	dummy.position = Vector2(411, 283)
	add_child(dummy)
	var npc := CHARACTER.instantiate() as MudCharacter
	npc.player_controlled = false
	npc.position = Vector2(155, 281)
	add_child(npc)
	npc.body_renderer.mud_color = Color("87704b")
	npc.weapons.equip(null)
	npc.equipment.toggle()
	npc.rig.time = 1.8
	crowd.append(npc)

func platform(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func cycle_crowd() -> void:
	crowd_mode = (crowd_mode + 1) % 3
	for npc in crowd: npc.queue_free()
	crowd.clear()
	var count := [1, 9, 29][crowd_mode] as int
	for i in count:
		var npc := CHARACTER.instantiate() as MudCharacter
		npc.player_controlled = false
		npc.position = Vector2(35 + (i % 15) * 40, 281 - (i / 15) * 95)
		add_child(npc)
		npc.rig.time = i * 0.31
		npc.rig.gait.phase = fposmod(i * 0.31, 1.0)
		npc.body_renderer.mud_color = Color.from_hsv(0.18 + i * 0.005, 0.42, 0.45 + (i % 3) * 0.08)
		npc.weapons.equip(null)
		npc.equipment.toggle()
		crowd.append(npc)

func _process(delta: float) -> void:
	elapsed += delta
	frame += 1
	if Input.is_action_just_pressed("crowd"): cycle_crowd()
	if Input.is_action_just_pressed("reset"):
		player.position = Vector2(285, 280)
		player.velocity = Vector2.ZERO
	for i in crowd.size():
		var npc := crowd[i]
		if crowd_mode > 0:
			npc.set_intent(sin(elapsed * 0.7 + i) * 0.25, false, fmod(elapsed + i * 0.2, 2.1) < delta)
	queue_redraw()
	if "--capture" in OS.get_cmdline_user_args() and frame == 80:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/mvp_preview.png")
		get_tree().quit()

func label_at(p: Vector2, value: String, size := 11, color := Color("a3b5af")) -> void:
	draw_string(font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if not font or not is_instance_valid(player): return
	draw_rect(Rect2(0, 0, 640, 360), Color("101d24"))
	# Restrained architectural backdrop, kept below character silhouettes.
	for x in range(16, 640, 32): draw_line(Vector2(x, 81), Vector2(x, 284), Color("17272c"))
	for y in range(92, 285, 32): draw_line(Vector2(0, y), Vector2(640, y), Color("17272c"))
	draw_rect(Rect2(25, 110, 590, 153), Color("132329"))
	for x in [43, 590]:
		draw_rect(Rect2(x, 99, 7, 185), Color("293a3b"))
		draw_rect(Rect2(x + 2, 108, 2, 164), Color("344643"))
	draw_line(Vector2(0, 284), Vector2(640, 284), Color("8c9764"), 2)
	draw_rect(Rect2(0, 286, 640, 34), Color("26332f"))
	for x in range(0, 640, 20): draw_rect(Rect2(x, 287 + (x % 3), 12, 2), Color("3b4838"))
	draw_rect(Rect2(0, 0, 640, 78), Color("0c161d"))
	draw_rect(Rect2(18, 16, 3, 29), Color("c1d18b"))
	label_at(Vector2(30, 29), "MIRE / MOTION LAB", 20, Color("e0e7cc"))
	label_at(Vector2(31, 45), "PROCEDURAL HUMANOID     /     PLAYABLE PROTOTYPE 01", 9)
	label_at(Vector2(31, 66), "FLOAT RIG   +   SOFT JOINTS   +   SDF BODY   +   PIXEL OUTPUT", 9, Color("81947e"))
	label_at(Vector2(467, 23), "GODOT 4.7  /  2D", 10, Color("bfd08c"))
	label_at(Vector2(467, 40), "%02d ACTORS    %d FPS" % [crowd.size() + 1, Engine.get_frames_per_second()], 10)
	label_at(Vector2(467, 57), "T  population: 2 / 10 / 30", 9)
	label_at(Vector2(65, 135), "01 / UNARMORED", 9, Color("829582"))
	label_at(Vector2(243, 135), "02 / PLAYABLE", 9, Color("b9c996"))
	label_at(Vector2(389, 135), "03 / STRIKE TARGET", 9, Color("829582"))
	label_at(Vector2(453, 173), "LIVE TELEMETRY", 10, Color("c3d29a"))
	var weapon_name := player.weapons.current.weapon_name if player.weapons.current else "None"
	var lines: Array[String] = ["STATE   " + String(player.state), "VEL     %5.1f / %5.1f" % [player.velocity.x, player.velocity.y], "ELBOW   %3.0f deg" % player.rig.angles.get("ArmFront", 0), "KNEE    %3.0f deg" % player.rig.angles.get("LegFront", 0), "COMP    %.2f" % player.rig.compressions.get("ArmFront", 0), "REACH   %.3f" % player.rig.stretch, "WEAPON  " + weapon_name, "HITS    %02d" % dummy.hit_count]
	for i in lines.size(): label_at(Vector2(453, 189 + i * 11), lines[i], 9)
	draw_rect(Rect2(0, 320, 640, 40), Color("0c161d"))
	label_at(Vector2(20, 335), "A D  RUN   SHIFT  WALK   SPACE  JUMP   J / LMB  ATTACK   E  ARMOR", 10, Color("d1d9b7"))
	label_at(Vector2(20, 350), "1  SWORD     2  UNARMED     F1  JOINTS     R  RESET     T  CROWD", 9)
