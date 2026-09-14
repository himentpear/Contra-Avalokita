extends Node

const GameSessionScript := preload("res://gameplay/session/game_session.gd")

@export var startup_config: StartupConfig

func _ready() -> void:
	if startup_config == null:
		startup_config = StartupConfig.new()
	var loader := PackageLoader.new()
	var manifests := loader.mount_packages()
	var resolved := DependencyResolver.resolve(manifests)
	if not resolved.ok:
		push_error("Package initialization failed: %s" % resolved.error)
		return
	ContentRegistry.clear()
	for manifest: ContentManifest in resolved.ordered:
		var error: Error = ContentRegistry.register_manifest(manifest)
		if error != OK:
			push_error("Could not register package %s: %s" % [manifest.id, error_string(error)])
			return
	var settings_error: Error = Settings.load_settings()
	if settings_error != OK:
		push_warning("Settings were not loaded: %s" % error_string(settings_error))
	var save_error: Error = SaveManager.initialize()
	if save_error != OK:
		push_error("Save system initialization failed: %s" % error_string(save_error))
		return
	Game.start_session(GameSessionScript.new())
	get_tree().call_deferred("change_scene_to_file", startup_config.initial_scene)
