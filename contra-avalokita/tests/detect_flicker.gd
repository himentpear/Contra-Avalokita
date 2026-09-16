extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Simulating Character Movement to Detect Flicker ---")
	var scene: PackedScene = preload("res://scenes/test_arena.tscn")
	var arena = scene.instantiate()
	root.add_child(arena)
	
	for i in range(5):
		await process_frame
		
	var player = arena.get_node("World/GameplayWorld/Player")
	var controller = player.get_node("Visual/CharacterLightingController")
	var body_renderer = player.get_node("Visual/MudBodyRenderer")
	
	var lamp = arena.get_node("World/Lighting/GameplayLights/StationLamp1/PointLight2D")
	print("Lamp global pos: ", lamp.global_position)
	
	var prev_energy = controller.current_energy
	var prev_dir = controller.current_direction
	var prev_local_dir = Vector2.ZERO
	
	# Move player horizontally across the lamp in 1-pixel increments
	# from X = 200 to X = 600 (lamp is at X = 345, Y = -74; player Y = 136)
	var flicker_detected = false
	for x in range(200, 600):
		player.global_position.x = float(x)
		player._sync_visual(0.016)
		controller._process(0.016)
		
		var dist = (lamp.global_position - player.global_position).length()
		var energy = controller.current_energy
		var dir = controller.current_direction
		var local_dir = controller._to_item_local_dir(body_renderer, dir)
		
		var energy_delta = absf(energy - prev_energy)
		var angle_delta = absf(prev_dir.angle_to(dir))
		var local_angle_delta = absf(prev_local_dir.angle_to(local_dir)) if x > 200 else 0.0
		
		if energy_delta > 0.05 or angle_delta > 0.1 or local_angle_delta > 0.1:
			print("FLICKER at X=", x, " dist=", dist, ":")
			print("  energy: prev=", prev_energy, " curr=", energy, " delta=", energy_delta)
			print("  dir: prev=", prev_dir, " curr=", dir, " angle_delta=", angle_delta)
			print("  local_dir: prev=", prev_local_dir, " curr=", local_dir, " local_angle_delta=", local_angle_delta)
			flicker_detected = true
			
		prev_energy = energy
		prev_dir = dir
		prev_local_dir = local_dir
	
	if not flicker_detected:
		print("No controller-level flicker detected between X=200 and X=600.")
		
	# Now let's test larger distance range: up to 1000px away
	print("\n-- Testing wide range X=0 to X=1500 --")
	for x in range(0, 1500, 5):
		player.global_position.x = float(x)
		player._sync_visual(0.016)
		controller._process(0.016)
		
		var dist = (lamp.global_position - player.global_position).length()
		var energy = controller.current_energy
		var dir = controller.current_direction
		var local_dir = controller._to_item_local_dir(body_renderer, dir)
		
		var energy_delta = absf(energy - prev_energy)
		var angle_delta = absf(prev_dir.angle_to(dir))
		
		if energy_delta > 0.08 or angle_delta > 0.15:
			print("WIDE FLICKER at X=", x, " dist=", dist, ":")
			print("  energy delta=", energy_delta, " angle delta=", angle_delta)
			
		prev_energy = energy
		prev_dir = dir
		prev_local_dir = local_dir

	arena.queue_free()
	quit(0)
