extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func ticks(count: int) -> void:
	for _i in count:
		await physics_frame


func run() -> void:
	var arena := load("res://tests/character/test_arena.tscn").instantiate() as Node2D
	root.add_child(arena)
	var victim: MudCharacter = arena.player
	victim.player_controlled = false
	await ticks(12)

	var hit := HitEvent.new(8.0, Vector2.LEFT, victim.global_position, 60.0, 10.0, &"LightHit", &"punch")
	hit.impact = 0.50
	victim.receive_hit(hit)
	var initial_amount: float = victim.body_renderer.hit_flash_amount
	check(initial_amount > 0.70, "Confirmed damage immediately starts a bright body flash")
	check(is_equal_approx(float(victim.body_renderer.shader_material.get_shader_parameter("hit_flash_amount")), initial_amount), "Primary SDF shader receives flash intensity")
	var all_depth_layers_match := true
	for material in victim.body_renderer.depth_materials:
		all_depth_layers_match = all_depth_layers_match and is_equal_approx(float(material.get_shader_parameter("hit_flash_amount")), initial_amount)
	check(all_depth_layers_match, "Rear/body/front SDF layers flash together")

	await ticks(1)
	var decayed_amount: float = victim.body_renderer.hit_flash_amount
	check(decayed_amount > 0.0 and decayed_amount < initial_amount, "Flash decays in real time while local hitstop is active")
	victim.trigger_hit_flash(hit)
	check(victim.body_renderer.hit_flash_amount >= decayed_amount, "Repeated hits extend rather than cancel the active flash")

	await ticks(16)
	check(victim.body_renderer.hit_flash_amount == 0.0, "Flash returns exactly to the original material state")
	victim.queue_free()
	arena.queue_free()
	await process_frame
	print("HIT FLASH RESULT: ", failures, " failures")
	quit(1 if failures else 0)
