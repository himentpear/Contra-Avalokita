class_name CoyoteItem
extends Resource

@export var id: StringName
@export var display_name := ""
@export var rarity: StringName = &"UNCOMMON"
@export_multiline var mechanical_text := ""
@export_multiline var flavor_text := ""
@export var tags: Array[StringName] = [&"UNFALLEN", &"MOVEMENT"]
@export var icon: Texture2D
@export var modifiers: Dictionary = {}
