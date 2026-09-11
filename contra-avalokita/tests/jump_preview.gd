extends SceneTree
## Captures the redesigned Jump/Fall/Land animation sequence with Godot's actual SDF renderer.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/jump_frames")
	var stage := Node2D.new()
	root.add_child(stage)
	
	var ground := Line2D.new()
	ground.points = PackedVector2Array([Vector2(0, 240), Vector2(640, 240)])
	ground.width = 1
	ground.default_color = Color("385078")
	stage.add_child(ground)
	
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	actor.position = Vector2(320, 240)
	actor.scale = Vector2(2.5, 2.5)
	stage.add_child(actor)
	actor.set_physics_process(false)
	actor.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	
	# The 11 frames of the jump sequence:
	var sequence = [
		{"anim": &"Idle", "time": 0.0,  "label": "F00_Idle"},
		{"anim": &"Jump", "time": 0.0,  "label": "F01_Takeoff"},
		{"anim": &"Jump", "time": 0.10, "label": "F02_AscentStretch"},
		{"anim": &"Jump", "time": 0.22, "label": "F03_AscentTuck"},
		{"anim": &"Jump", "time": 0.38, "label": "F04_ApexFloat"},
		{"anim": &"Fall", "time": 0.0,  "label": "F05_DescentStart"},
		{"anim": &"Fall", "time": 0.16, "label": "F06_FallingDive"},
		{"anim": &"Fall", "time": 0.35, "label": "F07_PreLandingReach"},
		{"anim": &"Land", "time": 0.0,  "label": "F08_ImpactSquash"},
		{"anim": &"Land", "time": 0.08, "label": "F09_RecoveryRise"},
		{"anim": &"Land", "time": 0.16, "label": "F10_StandSettle"}
	]
	
	for i in sequence.size():
		var item = sequence[i]
		actor.state = item["anim"]
		actor.anim_player.play(item["anim"], 0.0)
		actor.anim_player.seek(item["time"], true)
		actor._sync_visual(1.0 / 30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/jump_frames/%02d_%s.png" % [i, item["label"]])
	
	print("Successfully captured 11 jump frames in Godot.")
	
	actor.rig.character = null
	actor.rig = null
	actor.queue_free()
	stage.queue_free()
	await process_frame
	quit()
