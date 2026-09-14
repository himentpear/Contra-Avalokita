@tool
class_name RotoBoneMudCharacterAdapter
extends RefCounted

const TEMPLATE_PATH := "res://scenes/mud_character.tscn"
const DEFAULT_MAP_PATH := "res://addons/rotobone/v3/core/mud_character_bone_map.json"
const SemanticMapper := preload("res://addons/rotobone/v3/core/semantic_bone_mapper.gd")

var instance: Node
var character_body: CharacterBody2D
var skeleton: Skeleton2D
var animation_player: AnimationPlayer
var semantic_map: Dictionary = {}
var hierarchy: Array[Dictionary] = []
var _owns_instance := false


func load_template() -> bool:
	var packed := load(TEMPLATE_PATH) as PackedScene
	if packed == null:
		return false
	return bind_instance(packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), true)


func bind_instance(root: Node, owns_instance := false) -> bool:
	clear()
	instance = root
	_owns_instance = owns_instance
	character_body = _find_first_of_type(root, "CharacterBody2D") as CharacterBody2D
	skeleton = _find_first_of_type(root, "Skeleton2D") as Skeleton2D
	animation_player = _find_first_of_type(root, "AnimationPlayer") as AnimationPlayer
	if character_body == null or skeleton == null or animation_player == null:
		return false
	var mapper := SemanticMapper.new()
	semantic_map = mapper.map_skeleton(skeleton)
	hierarchy = mapper.extract_hierarchy(skeleton)
	return true


func find_template_instance(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	if scene_root.scene_file_path == TEMPLATE_PATH:
		return scene_root
	for child in scene_root.get_children():
		var found := find_template_instance(child)
		if found != null:
			return found
	return null


func bind_from_edited_scene(scene_root: Node) -> bool:
	var found := find_template_instance(scene_root)
	return found != null and bind_instance(found)


func available_animations() -> PackedStringArray:
	var names := PackedStringArray()
	if animation_player == null:
		return names
	for name in animation_player.get_animation_list():
		names.append(String(name))
	return names


func mapping_document() -> Dictionary:
	if skeleton == null:
		return {}
	return SemanticMapper.new().mapping_document(skeleton, TEMPLATE_PATH)


func write_mapping(path := DEFAULT_MAP_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(mapping_document(), "\t") + "\n")
	return OK


func clear(free_owned_instance := true) -> void:
	if free_owned_instance and _owns_instance and is_instance_valid(instance) and not instance.is_inside_tree():
		instance.free()
	instance = null
	character_body = null
	skeleton = null
	animation_player = null
	semantic_map.clear()
	hierarchy.clear()
	_owns_instance = false


func _find_first_of_type(node: Node, type_name: StringName) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_first_of_type(child, type_name)
		if found != null:
			return found
	return null
