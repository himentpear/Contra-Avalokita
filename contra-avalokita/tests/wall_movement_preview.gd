extends SceneTree
## Captures the procedural cling, slide and wall-push silhouettes.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var stage := Node2D.new()
	root.add_child(stage)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(640, 360)
	backdrop.color = Color("101d24")
	stage.add_child(backdrop)

	var title := Label.new()
	title.text = "WALL ACTION SILHOUETTES"
	title.position = Vector2(18, 16)
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color("d8e6bd")
	stage.add_child(title)

	var samples := [
		{"action": &"WallHang", "clip": &"Wall/Hang", "time": 0.12, "label": "扒墙 / HANG"},
		{"action": &"WallSlide", "clip": &"Wall/Slide", "time": 0.18, "label": "滑墙 / SLIDE"},
		{"action": &"WallPush", "clip": &"Wall/Push", "time": 0.025, "label": "蹬墙 / PUSH"},
		{"action": &"WallRelease", "clip": &"Wall/Release", "time": 0.075, "label": "离墙 / RELEASE"},
	]
	for i in samples.size():
		var x := 74.0 + i * 154.0
		var wall := ColorRect.new()
		wall.position = Vector2(x + 38, 78)
		wall.size = Vector2(13, 214)
		wall.color = Color("4c6255")
		stage.add_child(wall)
		var edge := ColorRect.new()
		edge.position = Vector2(x + 35, 78)
		edge.size = Vector2(3, 214)
		edge.color = Color("849678")
		stage.add_child(edge)

		var holder := Node2D.new()
		holder.position = Vector2(x, 246)
		holder.scale = Vector2(2.0, 2.0)
		stage.add_child(holder)
		var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		actor.player_controlled = false
		holder.add_child(actor)
		actor.set_physics_process(false)
		actor.weapons.equip(null)
		actor.state = &"Fall"
		actor.anim_player.play(&"Air/Fall", 0.0)
		actor.anim_player.seek(0.12, true)
		actor.wall_side = 1.0
		actor.facing = 1.0
		actor.wall_surface_x = x + 35.0
		actor.wall_hand_anchor_y = 144.0
		actor.wall_foot_anchor_y = 202.0
		actor.wall_action = samples[i].action
		actor.wall_action_time = samples[i].time
		actor.anim_player.play(samples[i].clip, 0.0)
		actor.anim_player.seek(samples[i].time, true)
		actor.anim_player.advance(0.0)
		actor.pose_composer.evaluate(0.0)
		actor._sync_visual(0.0)

		var label := Label.new()
		label.text = samples[i].label
		label.position = Vector2(x - 45, 306)
		label.size = Vector2(125, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.modulate = Color("aabd7d")
		stage.add_child(label)

	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://artifacts/wall_movement_preview.png")
	print("Captured wall_movement_preview.png")
	quit()
