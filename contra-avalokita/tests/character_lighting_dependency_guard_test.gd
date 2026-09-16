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
	print("--- Running Character Lighting Dependency Guard Test ---")
	
	var forbidden_tokens: Array[String] = [
		"MudCharacter",
		"mud_character",
		"characters/mud",
		"mud_lighting"
	]
	
	var target_dirs: Array[String] = [
		"res://scripts/presentation/lighting",
		"res://shaders/character"
	]
	
	for dir_path in target_dirs:
		_check_directory(dir_path, forbidden_tokens)
	
	if failures == 0:
		print("=== ALL CHARACTER LIGHTING DEPENDENCY GUARD TESTS PASSED ===")
		quit(0)
	else:
		push_error("=== %d TESTS FAILED ===" % failures)
		quit(1)

func _check_directory(dir_path: String, forbidden_tokens: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		failures += 1
		push_error("FAIL: Could not open directory: " + dir_path)
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".gd") or file_name.ends_with(".gdshader")):
			var full_path = dir_path.path_join(file_name)
			_scan_file(full_path, forbidden_tokens)
		file_name = dir.get_next()
	dir.list_dir_end()

func _scan_file(file_path: String, forbidden_tokens: Array[String]) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		failures += 1
		push_error("FAIL: Could not open file for reading: " + file_path)
		return
	
	var content := file.get_as_text()
	file.close()
	
	var clean := true
	for token in forbidden_tokens:
		if content.find(token) != -1:
			clean = false
			failures += 1
			push_error("FAIL: Forbidden token '%s' found in generic lighting file: %s" % [token, file_path])
	
	if clean:
		print("PASS: %s is free of character-specific dependencies" % file_path)
