class_name DataModLoader
extends RefCounted

const SAFE_RESOURCE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "svg", "ogg", "wav", "mp3", "json"]

func load_manifests(root_path: String = "user://mods") -> Array:
	var result: Array = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	var root := DirAccess.open(root_path)
	if root == null:
		return result
	for directory_name in root.get_directories():
		var manifest_path := root_path.path_join(directory_name).path_join("manifest.json")
		var manifest := _load_manifest(manifest_path, directory_name)
		if manifest != null:
			result.append(manifest)
	return result

func _load_manifest(path: String, directory_name: String) -> ContentManifest:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Ignoring invalid data mod manifest: %s" % path)
		return null
	var data: Dictionary = parsed
	var mod_id := StringName(data.get("mod_id", ""))
	if mod_id.is_empty() or String(mod_id) != directory_name or mod_id in [&"base", &"core"]:
		push_warning("Ignoring data mod with invalid or mismatched mod_id: %s" % path)
		return null
	var manifest := ContentManifest.new()
	manifest.id = mod_id
	manifest.display_name = String(data.get("display_name", directory_name))
	manifest.version = String(data.get("version", "0.0.0"))
	manifest.content_type = "mod"
	manifest.dependencies = PackedStringArray(data.get("dependencies", []))
	manifest.minimum_game_version = String(data.get("minimum_game_version", "0.0.0"))
	manifest.contains_executable_code = false
	for entry_value: Variant in data.get("definitions", []):
		if typeof(entry_value) != TYPE_DICTIONARY:
			return null
		var definition := _definition_from_data(entry_value, mod_id, path.get_base_dir())
		if definition == null:
			return null
		manifest.definitions.append(definition)
	return manifest

func _definition_from_data(data: Dictionary, mod_id: StringName, base_dir: String) -> ContentDefinition:
	var definition := ContentDefinition.new()
	definition.id = StringName(data.get("id", ""))
	definition.content_type = StringName(data.get("type", ""))
	definition.display_name = String(data.get("display_name", definition.id))
	for tag: Variant in data.get("tags", []):
		definition.tags.append(StringName(tag))
	definition.metadata = data.get("metadata", {}).duplicate(true)
	definition.metadata["data_only"] = true
	var relative_path := String(data.get("resource", ""))
	if not relative_path.is_empty():
		var extension := relative_path.get_extension().to_lower()
		if not SAFE_RESOURCE_EXTENSIONS.has(extension) or relative_path.is_absolute_path() or ".." in relative_path.split("/"):
			return null
		var resource_path := base_dir.path_join(relative_path)
		if not FileAccess.file_exists(resource_path) or extension == "json":
			definition.metadata["resource_path"] = resource_path
		else:
			definition.resource = load(resource_path)
		if definition.resource == null and not FileAccess.file_exists(resource_path):
			return null
	return definition
