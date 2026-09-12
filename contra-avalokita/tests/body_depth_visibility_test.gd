extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena := preload("res://scenes/test_arena.tscn").instantiate()
	root.add_child(arena)
	var actor: MudCharacter = arena.player
	actor.player_controlled = false
	for frame in 12: await physics_frame
	actor.set_physics_process(false)
	actor.state = &"Run"
	actor.anim_player.play(&"Run",0)
	actor.anim_player.seek(.10,true)
	actor._sync_visual(0)
	var rear := actor.body_renderer.get_node("RearSurface") as CanvasItem
	var front := actor.body_renderer.get_node("FrontSurface") as CanvasItem
	assert(actor.visual.z_index+rear.z_index > arena.z_index,"Rear limb pass must remain above arena background")
	assert(rear.z_index < front.z_index,"Preserve internal occlusion order")
	for facing in [1.0,-1.0]:
		actor.facing = facing
		actor._sync_visual(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/leg_visibility_%s.png" % ("right" if facing > 0 else "left"))
	print("PASS: rear/front limb passes above background in both facings")
	for child in arena.find_children("*","CharacterBody2D"):
		if child is MudCharacter and child.rig:
			child.rig.character = null
			child.rig.gait = null
			child.rig = null
	arena.queue_free()
	await process_frame
	quit()
