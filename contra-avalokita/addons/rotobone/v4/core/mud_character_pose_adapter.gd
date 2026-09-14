@tool
class_name MudCharacterPoseAdapterV4
extends RefCounted

const DEFAULT_SCENE := "res://scenes/mud_character.tscn"

var character: Node
var skeleton: Skeleton2D
var animation_player: AnimationPlayer
var semantic_map: Dictionary = {}


func detect(root: Node) -> bool:
	clear()
	character = root
	skeleton = _find_type(root, "Skeleton2D") as Skeleton2D
	animation_player = _find_type(root, "AnimationPlayer") as AnimationPlayer
	if skeleton == null:
		return false
	semantic_map = {
		"root": _path_for("Pelvis"),
		"body": _path_for("Torso"),
		"head": _path_for("Head"),
		"arm_r": _path_for("UpperArmFront"),
		"forearm_r": _path_for("ForearmFront"),
		"hand_r": _path_for("HandFront"),
		"arm_l": _path_for("UpperArmBack"),
		"forearm_l": _path_for("ForearmBack"),
		"hand_l": _path_for("HandBack"),
		"leg_r": _path_for("ThighFront"),
		"shin_r": _path_for("ShinFront"),
		"foot_r": _path_for("FootFront"),
		"leg_l": _path_for("ThighBack"),
		"shin_l": _path_for("ShinBack"),
		"foot_l": _path_for("FootBack"),
	}
	return not String(semantic_map["root"]).is_empty() and not String(semantic_map["body"]).is_empty()


func instantiate_template() -> Node:
	var packed := load(DEFAULT_SCENE) as PackedScene
	return packed.instantiate() if packed != null else null


func clear() -> void:
	character = null
	skeleton = null
	animation_player = null
	semantic_map.clear()


func _path_for(bone_name: String) -> String:
	var bone := skeleton.find_child(bone_name, true, false) as Bone2D
	return String(skeleton.get_path_to(bone)) if bone != null else ""


func _find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_type(child, type_name)
		if found != null:
			return found
	return null
