class_name ContentManifest
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var version: String = "0.0.0"
@export_enum("base", "dlc", "mod") var content_type: String = "mod"
@export var dependencies: PackedStringArray = []
@export var minimum_game_version: String = "0.0.0"
@export var contains_executable_code: bool = false
@export var definitions: Array[Resource] = []
