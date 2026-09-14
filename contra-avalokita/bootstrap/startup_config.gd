class_name StartupConfig
extends Resource

enum RuntimeMode { DEVELOPMENT, PRODUCTION }

@export var runtime_mode := RuntimeMode.DEVELOPMENT
@export_file("*.tscn") var development_initial_scene := "res://scenes/test_arena.tscn"
@export_file("*.tscn") var production_initial_scene := ""
@export var development_load_test_packages := true
@export var production_load_test_packages := false

func resolved_initial_scene() -> String:
	if runtime_mode == RuntimeMode.PRODUCTION and not production_initial_scene.is_empty() and ResourceLoader.exists(production_initial_scene):
		return production_initial_scene
	return development_initial_scene

func should_load_test_packages() -> bool:
	return development_load_test_packages if runtime_mode == RuntimeMode.DEVELOPMENT else production_load_test_packages
