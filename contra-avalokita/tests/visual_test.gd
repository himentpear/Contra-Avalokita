extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func ticks(count: int) -> void:
	for i in count: await physics_frame

func capture(id: String) -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/" + id + ".png")

func run() -> void:
	var arena := load("res://scenes/test_arena.tscn").instantiate() as Node2D
	root.add_child(arena)
	var p: MudCharacter = arena.player
	p.player_controlled = false
	await ticks(80)
	await capture("mvp_preview")
	p.set_intent(1)
	await ticks(16)
	await capture("run")
	p.set_intent(0, true)
	await ticks(12)
	await capture("jump")
	await ticks(65)
	p.position = Vector2(370, 281)
	p.set_intent(0, false, true)
	await ticks(16)
	await capture("attack")
	await ticks(30)
	arena.cycle_crowd()
	arena.cycle_crowd()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await ticks(60)
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	var sample_count := 6 if DisplayServer.get_name() == "headless" else 180
	for i in sample_count:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	var median_idx := times.size() / 2
	var p95_idx := int(times.size() * 0.95)
	print("RENDER BENCH 30 actors | median ms: %.2f | p95 ms: %.2f | renderer: %s" % [times[median_idx], times[p95_idx], RenderingServer.get_video_adapter_name()])
	await capture("crowd_30")
	quit()
