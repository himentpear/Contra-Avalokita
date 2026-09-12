extends SceneTree
## Captures one real physics-driven wall movement loop for GIF export.

var actor: MudCharacter
var status: Label
var slide_ticks := 0
var jumped_from_wall := false

func _initialize() -> void:
	call_deferred("capture")

func platform(parent: Node, center: Vector2, size: Vector2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	var visual := ColorRect.new()
	visual.position = center - size * 0.5
	visual.size = size
	visual.color = color
	parent.add_child(visual)
	visual.z_index = -1

func label(parent: Node, text: String, position: Vector2, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.position = position
	result.add_theme_font_size_override("font_size", size)
	result.modulate = color
	parent.add_child(result)
	return result

func capture() -> void:
	Engine.physics_ticks_per_second = 60
	DirAccess.make_dir_recursive_absolute("res://artifacts/wall_movement_gif_frames")
	var stage := Node2D.new()
	root.add_child(stage)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(640, 360)
	backdrop.color = Color("101d24")
	stage.add_child(backdrop)
	platform(stage, Vector2(320, 320), Vector2(640, 40), Color("354941"))
	platform(stage, Vector2(430, 190), Vector2(20, 260), Color("53695a"))
	var edge := ColorRect.new()
	edge.position = Vector2(417, 60)
	edge.size = Vector2(3, 260)
	edge.color = Color("8b9d7d")
	stage.add_child(edge)

	label(stage, "WALL MOVEMENT", Vector2(20, 15), 18, Color("d8e6bd"))
	label(stage, "HANG  >  SLIDE  >  PUSH  >  RELEASE", Vector2(20, 42), 11, Color("9fb883"))
	status = label(stage, "", Vector2(20, 330), 10, Color("e4cf79"))

	actor = preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	actor.position = Vector2(365, 298)
	stage.add_child(actor)
	actor.weapons.equip(null)

	var output_frame := 0
	for physics_tick in 210:
		var jump_now := physics_tick == 12
		var intent := 1.0
		if actor.wall_action == &"WallSlide":
			slide_ticks += 1
			if slide_ticks >= 10 and not jumped_from_wall:
				jump_now = true
				jumped_from_wall = true
		elif jumped_from_wall and actor.is_on_floor():
			intent = 0.0
		elif jumped_from_wall:
			intent = -1.0
		actor.set_intent(intent, jump_now)
		await physics_frame
		status.text = "ACTION %-10s   PHASE %-10s   VX %4d   VY %4d" % [
			String(actor.wall_action), String(actor.jump_phase), int(actor.velocity.x), int(actor.velocity.y)
		]
		if physics_tick % 2 == 0:
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(
				"res://artifacts/wall_movement_gif_frames/%03d.png" % output_frame
			)
			output_frame += 1
	print("Captured ", output_frame, " wall movement GIF frames")
	quit()
