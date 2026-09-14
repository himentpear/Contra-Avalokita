extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func run() -> void:
	var ocean := preload("res://scenes/ocean_wave_test.tscn").instantiate()
	root.add_child(ocean)
	await process_frame

	var sea_body := ocean.get_node_or_null("SeaBody") as ColorRect
	check(sea_body != null, "Ocean test scene contains the full-screen SeaBody")
	check(ocean.get_node_or_null("Backdrop") is ColorRect, "Ocean test scene contains a black backdrop")
	check(ocean.get_node_or_null("HUD/DebugLabel") is Label, "Ocean test scene exposes runtime tuning instructions")

	var material := ocean.get_ocean_material() as ShaderMaterial
	check(material != null, "SeaBody owns a ShaderMaterial")
	if material != null:
		check(material.shader != null and material.shader.resource_path == "res://shaders/ocean_black_wave.gdshader", "Ocean test scene uses the procedural black ocean shader")
		check(is_equal_approx(float(material.get_shader_parameter("amplitude_px")), 8.0), "Medium preset starts at an 8px wave amplitude")

		ocean.add_impact(320.0, 6.0, 48.0)
		var impact := material.get_shader_parameter("impact0") as Vector4
		check(is_equal_approx(impact.x, 0.5) and is_equal_approx(impact.y, 0.0), "Local disturbance injection normalizes screen X and resets impact age")

		ocean.set_preset(&"storm")
		check(is_equal_approx(float(material.get_shader_parameter("amplitude_px")), 13.0), "Storm preset raises the procedural wave amplitude")
		check(is_equal_approx(float(material.get_shader_parameter("roughness")), 1.35), "Storm preset raises layered surface roughness")

	ocean.queue_free()
	await process_frame
	print("OCEAN WAVE SCENE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
