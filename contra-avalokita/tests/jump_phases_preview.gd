extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute("res://artifacts/jump_frames")
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1200,20)
	collision.shape = shape
	floor_body.position = Vector2(320,310)
	floor_body.add_child(collision)
	root.add_child(floor_body)
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(20,300),Vector2(620,300)])
	line.width = 1
	root.add_child(line)
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	actor.position = Vector2(200,296)
	actor.scale = Vector2(2,2)
	root.add_child(actor)
	var caption := Label.new()
	caption.position = Vector2(25,20)
	root.add_child(caption)
	for frame in 12: await physics_frame
	for frame in 120:
		actor.set_intent(.43,frame == 10)
		caption.text = "JUMP / "+String(actor.jump_phase).to_upper()+"\nMOVE / "+String(actor.state).to_upper()
		await physics_frame
		await RenderingServer.frame_post_draw
		if frame%2 == 0: root.get_texture().get_image().save_png("res://artifacts/jump_frames/%03d.png" % frame)
	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	floor_body.queue_free()
	await process_frame
	quit()
