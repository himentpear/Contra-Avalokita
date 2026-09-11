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
	bind("sprint", [KEY_SHIFT])
	bind("attack", [KEY_J])
	bind("equipment", [KEY_E])
	bind("weapon_sword", [KEY_1])
	bind("weapon_none", [KEY_2])
	bind("debug_rig", [KEY_F1])
	bind("crowd", [KEY_T])
	bind("reset", [KEY_R])
	bind("kill", [KEY_K])
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

@export var camera_shake_enabled := false
var camera_shake_offset := Vector2.ZERO
var camera_shake_timer := 0.0
var camera_shake_duration := 0.0
var camera_shake_dir := Vector2.RIGHT
var camera_shake_amp := 0.0

func trigger_camera_shake(dir: Vector2, amp: float, duration: float = 0.08) -> void:
	if not camera_shake_enabled:
		camera_shake_offset = Vector2.ZERO
		position = Vector2.ZERO
		return
	camera_shake_dir = dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	camera_shake_amp = amp
	camera_shake_duration = maxf(duration, 0.001)
	camera_shake_timer = camera_shake_duration
	camera_shake_offset = (camera_shake_dir * amp).round()
	position = camera_shake_offset

func _process(delta: float) -> void:
	elapsed += delta
	frame += 1
	if camera_shake_enabled and camera_shake_timer > 0.0:
		camera_shake_timer = maxf(0.0, camera_shake_timer - delta)
		var p: float = camera_shake_timer / camera_shake_duration
		var offset_val: float = cos((camera_shake_duration - camera_shake_timer) * 55.0) * camera_shake_amp * p
		camera_shake_offset = (camera_shake_dir * offset_val).round()
	else:
		camera_shake_offset = Vector2.ZERO
	position = camera_shake_offset

	if not is_instance_valid(player): return
	if Input.is_action_just_pressed("crowd"): cycle_crowd()
	if Input.is_action_just_pressed("kill"):
		player.die()
	if player.state == &"Dead" and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack")):
		player.rise()
	if Input.is_action_just_pressed("reset"):
		player.position = Vector2(285, 280)
		player.velocity = Vector2.ZERO
		player.revive()
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
	if player.rig.debug_draw:
		var gait_phase := player.anim_player.current_animation_position / maxf(player.anim_player.current_animation_length,.001)
		var action_phase := player.attack_time / maxf(player.attack_duration,.001) if player.is_attacking() else 0.0
		label_at(Vector2(18,91),"MOVE %s  ACTION %s  GAIT %.2f  ATTACK %.2f" % [player.state,player.action_state,gait_phase,action_phase],10)
		label_at(Vector2(18,105),"FLOOR %s  VY %.1f   GREEN: BASE  PINK: ACTION  GOLD: PELVIS" % [str(player.is_on_floor()),player.velocity.y],9)
	var lines: Array[String] = ["STATE   " + String(player.state), "VEL     %5.1f / %5.1f" % [player.velocity.x, player.velocity.y], "ELBOW   %3.0f deg" % player.rig.angles.get("ArmFront", 0), "KNEE    %3.0f deg" % player.rig.angles.get("LegFront", 0), "COMP    %.2f" % player.rig.compressions.get("ArmFront", 0), "REACH   %.3f" % player.rig.stretch, "WEAPON  " + weapon_name, "HITS    %02d" % dummy.hit_count]
	for i in lines.size(): label_at(Vector2(453, 189 + i * 11), lines[i], 9)
	draw_rect(Rect2(0, 320, 640, 40), Color("0c161d"))
	label_at(Vector2(20, 335), "A D  WALK   HOLD SHIFT  RUN   SPACE  JUMP   J / LMB  ATTACK   E  ARMOR", 10, Color("d1d9b7"))
	label_at(Vector2(20, 350), "1  SWORD   2  UNARMED   F1  JOINTS   K  DIE   SPACE  RISE   R  RESET   T  CROWD", 9)
