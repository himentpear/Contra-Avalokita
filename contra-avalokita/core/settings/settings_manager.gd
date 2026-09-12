extends Node

const SETTINGS_PATH := "user://settings.json"
var values: Dictionary = {}

func load_settings() -> Error:
	if not FileAccess.file_exists(SETTINGS_PATH):
		values = {}
		return OK
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR
	values = parsed
	return OK

func save_settings() -> Error:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(values, "\t"))
	return OK

func get_value(key: StringName, fallback: Variant = null) -> Variant:
	return values.get(String(key), fallback)

func set_value(key: StringName, value: Variant) -> void:
	values[String(key)] = value

