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
	var config := StartupConfig.new()
	check(config.runtime_mode == StartupConfig.RuntimeMode.DEVELOPMENT, "Development is the explicit default runtime mode")
	check(config.resolved_initial_scene() == "res://scenes/test_arena.tscn", "Development mode opens the test arena")
	check(config.should_load_test_packages(), "Development mode loads test packages")

	config.runtime_mode = StartupConfig.RuntimeMode.PRODUCTION
	check(config.resolved_initial_scene() == "res://scenes/test_arena.tscn", "Production mode has an explicit test-arena fallback until a menu exists")
	check(not config.should_load_test_packages(), "Production mode excludes test packages")
	config.production_initial_scene = "res://scenes/levels/bunker_station.tscn"
	check(config.resolved_initial_scene() == config.production_initial_scene, "Production mode selects a configured production entry")

	var production_manifests := PackageLoader.new().mount_packages(false)
	var has_test_package := false
	for manifest: ContentManifest in production_manifests:
		if String(manifest.id).to_lower().begins_with("test"):
			has_test_package = true
	check(not has_test_package, "Production package discovery filters test-prefixed DLC manifests")

	print("STARTUP CONFIG RESULT: ", failures, " failures")
	quit(1 if failures else 0)
