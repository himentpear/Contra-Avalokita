@tool
extends Node2D


func _ready() -> void:
	var weapon_slots := get_node_or_null("MudCharacter/Visual/WeaponSlots") as Node2D
	if weapon_slots != null:
		weapon_slots.visible = false
	_sync_renderer()


func _process(_delta: float) -> void:
	_sync_renderer()


func _sync_renderer() -> void:
	var skeleton := get_node_or_null("MudCharacter/Visual/PoseRoot/Skeleton2D") as Skeleton2D
	var renderer := get_node_or_null("MudCharacter/Visual/MudBodyRenderer")
	if skeleton != null and renderer != null and renderer.has_method("sync_skeleton"):
		renderer.call("sync_skeleton", skeleton)
