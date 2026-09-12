extends Node

const TEST_ROOT := "user://mods/loader_test_mod"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	var file := FileAccess.open(TEST_ROOT.path_join("manifest.json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({
		"mod_id": "loader_test_mod",
		"display_name": "Loader Test",
		"version": "1.0.0",
		"dependencies": ["base@>=0.2.0"],
		"definitions": [{"id": "loader_test_mod:relic", "type": "item", "display_name": "Relic", "tags": ["test"], "metadata": {"value": 1}}]
	}))
	file.close()
	var manifests := DataModLoader.new().load_manifests("user://mods")
	var found: ContentManifest
	for manifest: ContentManifest in manifests:
		if manifest.id == &"loader_test_mod":
			found = manifest
	assert(found != null)
	assert(not found.contains_executable_code)
	assert(found.definitions.size() == 1)
	assert(found.definitions[0].id == &"loader_test_mod:relic")
	assert(found.definitions[0].metadata.data_only)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ROOT.path_join("manifest.json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	print("DATA_MOD_LOADER_OK")
	get_tree().quit()

