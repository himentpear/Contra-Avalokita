extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func title(parent: Node, text: String, position: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color("d1d9b7")
	parent.add_child(label)

func run() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var background := ColorRect.new()
	background.color = Color("101d24")
	background.size = Vector2(640, 360)
	stage.add_child(background)
	title(stage, "MIRE / WHOLE-BODY LOCOMOTION", Vector2(18, 12), 18)
	title(stage, "WALK  /  CONTACT > DOWN > PASSING > UP > CONTACT", Vector2(18, 44), 11)
	title(stage, "RUN  /  STRIDE > SUSPENDED > CONTACT > PASSING > RECOVERY", Vector2(18, 195), 11)
	for row in 2:
		var y := 165.0 + row * 155.0
		var floor_line := ColorRect.new()
		floor_line.position = Vector2(0, y + 3)
		floor_line.size = Vector2(640, 1)
		floor_line.color = Color("596846")
		stage.add_child(floor_line)
		var count := 5 if row == 0 else 10
		for col in count:
			var actor := load("res://scenes/mud_character.tscn").instantiate() as MudCharacter
			actor.player_controlled = false
			actor.position = Vector2(64 + col * 128 if row == 0 else 32 + col * 64, y)
			stage.add_child(actor)
			actor.set_physics_process(false)
			actor.equipment.toggle()
			actor.weapons.equip(null)
			var target_phase: float = [0.0, 0.11, 0.25, 0.4, 0.5][col] if row == 0 else col / 10.0
			for i in 80:
				actor.rig.gait.phase = target_phase
				actor.rig.gait.weight = 1.0
				actor.rig.gait.run_mix = float(row)
				actor.rig.pose(1.0 / 60.0, &"Walk" if row == 0 else &"Run", Vector2(45 if row == 0 else 105, 0), 0, 0)
			actor.rig.gait.phase = target_phase
			actor.rig.pose(0, &"Walk" if row == 0 else &"Run", Vector2(45 if row == 0 else 105, 0), 0, 0)
			actor._sync_visual(0)
			title(stage, actor.rig.gait.phase_label(), Vector2(actor.position.x - 18, y + 9), 9)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/gait_cycles.png")
	quit()
