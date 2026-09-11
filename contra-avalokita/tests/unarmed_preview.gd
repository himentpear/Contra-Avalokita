extends SceneTree
## Captures and compares Armed (Sword) vs Unarmed (Lowered hanging arm) animations.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/unarmed_frames")
	var stage := Node2D.new()
	root.add_child(stage)
	
	var ground := Line2D.new()
	ground.points = PackedVector2Array([Vector2(0, 240), Vector2(640, 240)])
	ground.width = 1
	ground.default_color = Color("385078")
	stage.add_child(ground)
	
	var actions = [
		{"anim": &"Idle", "label": "00_Idle"},
		{"anim": &"Walk", "label": "01_Walk_Push"},
		{"anim": &"Walk", "label": "02_Walk_Pass", "time": 0.20},
		{"anim": &"Run",  "label": "03_Sprint_Push"},
		{"anim": &"Run",  "label": "04_Sprint_Flight", "time": 0.22},
		{"anim": &"Jump", "label": "05_Jump_Apex", "time": 0.38},
		{"anim": &"Fall", "label": "06_Fall_Dive", "time": 0.16},
		{"anim": &"Land", "label": "07_Land_Squash", "time": 0.0}
	]
	
	# Column 0: Armed (Sword) at x=200
	# Column 1: Unarmed (Lowered Arm) at x=440
	var actor_armed := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor_armed.player_controlled = false
	actor_armed.position = Vector2(200, 240)
	actor_armed.scale = Vector2(2.5, 2.5)
	stage.add_child(actor_armed)
	actor_armed.set_physics_process(false)
	actor_armed.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	
	var actor_unarmed := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor_unarmed.player_controlled = false
	actor_unarmed.position = Vector2(440, 240)
	actor_unarmed.scale = Vector2(2.5, 2.5)
	stage.add_child(actor_unarmed)
	actor_unarmed.set_physics_process(false)
	actor_unarmed.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor_unarmed.weapons.equip(null)
	
	for item in actions:
		var base_anim: StringName = item["anim"]
		var unarmed_anim: StringName = StringName(String(base_anim) + "_Unarmed")
		var t: float = item.get("time", 0.0)
		
		actor_armed.state = base_anim
		actor_armed.anim_player.play(base_anim, 0.0)
		actor_armed.anim_player.seek(t, true)
		actor_armed._sync_visual(1.0 / 30.0)
		
		actor_unarmed.state = base_anim
		actor_unarmed.anim_player.play(unarmed_anim if actor_unarmed.anim_player.has_animation(unarmed_anim) else base_anim, 0.0)
		actor_unarmed.anim_player.seek(t, true)
		actor_unarmed._sync_visual(1.0 / 30.0)
		
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/unarmed_frames/%s.png" % item["label"])
	
	print("Successfully captured armed vs unarmed comparison frames.")
	
	actor_armed.rig.character = null
	actor_armed.rig = null
	actor_armed.queue_free()
	actor_unarmed.rig.character = null
	actor_unarmed.rig = null
	actor_unarmed.queue_free()
	stage.queue_free()
	await process_frame
	quit()
