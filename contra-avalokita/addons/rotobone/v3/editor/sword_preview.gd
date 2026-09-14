@tool
class_name RotoBoneSwordPreview
extends Node2D

@export_node_path("Skeleton2D") var skeleton_path := NodePath("../MudCharacterInstance/Visual/PoseRoot/Skeleton2D")
@export_node_path("Node2D") var sword_path := NodePath("Sword")


func _ready() -> void:
	set_process(true)
	sync_to_hand()


func _process(_delta: float) -> void:
	sync_to_hand()


func sync_to_hand() -> bool:
	var skeleton := get_node_or_null(skeleton_path) as Skeleton2D
	var sword := get_node_or_null(sword_path) as Node2D
	if skeleton == null or sword == null:
		return false
	var hand := skeleton.get_node_or_null("Pelvis/Torso/UpperArmFront/ForearmFront/HandFront") as Bone2D
	if hand == null:
		return false
	sword.global_position = hand.global_position
	sword.global_rotation = hand.global_rotation
	return true
