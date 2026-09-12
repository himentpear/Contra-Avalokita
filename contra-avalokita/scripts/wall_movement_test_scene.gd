extends Node2D
## Interactive arena for WallHang, WallSlide and WallJump.

const CHARACTER := preload("res://scenes/mud_character.tscn")
var player: MudCharacter
var status: Label

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
	bind("reset", [KEY_R])

func bind(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for code in keys:
		var already_bound := false
		for existing in InputMap.action_get_events(action):
			if existing is InputEventKey and existing.physical_keycode == code:
				already_bound = true
				break
		if not already_bound:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	platform(Vector2(320, 342), Vector2(640, 28))
	platform(Vector2(266, 220), Vector2(18, 230))
	platform(Vector2(470, 188), Vector2(18, 294))
	platform(Vector2(368, 72), Vector2(220, 16))

	player = CHARACTER.instantiate() as MudCharacter
	player.position = Vector2(112, 326)
	add_child(player)

	var title := Label.new()
	title.text = "WALL MOVEMENT TEST"
	title.position = Vector2(18, 14)
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color("d8e6bd")
	add_child(title)

	var help := Label.new()
	help.text = "A/D 移动  |  SPACE 跳跃/蹬墙  |  朝墙持续输入：扒墙 → 滑墙  |  R 重置"
	help.position = Vector2(18, 42)
	help.add_theme_font_size_override("font_size", 11)
	help.modulate = Color("9fb883")
	add_child(help)

	status = Label.new()
	status.position = Vector2(18, 318)
	status.add_theme_font_size_override("font_size", 10)
	status.modulate = Color("e4cf79")
	add_child(status)
	queue_redraw()

func platform(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	body.set_meta("draw_rect", Rect2(center - size * 0.5, size))

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		player.revive()
		player.position = Vector2(112, 326)
		player.velocity = Vector2.ZERO
	status.text = "ACTION %-10s  PHASE %-10s  VELOCITY (%4d, %4d)" % [
		String(player.wall_action), String(player.jump_phase), int(player.velocity.x), int(player.velocity.y)
	]
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("101d24"), true)
	for child in get_children():
		if child is StaticBody2D and child.has_meta("draw_rect"):
			var rect: Rect2 = child.get_meta("draw_rect")
			draw_rect(rect, Color("354941"), true)
			draw_rect(rect, Color("718365"), false, 2.0)
	draw_dashed_line(Vector2(276, 205), Vector2(458, 205), Color("52695c"), 1.0, 5.0)
