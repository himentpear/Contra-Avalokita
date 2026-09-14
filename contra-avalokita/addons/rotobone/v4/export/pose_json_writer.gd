@tool
class_name RotoPoseJSONWriter
extends RefCounted


func write_json(path: String, data: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "  "))
	return OK
