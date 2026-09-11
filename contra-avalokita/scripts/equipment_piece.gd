class_name EquipmentPiece
extends Node2D
@export var texture: Texture2D
@export var offset := Vector2.ZERO
@export var rotation_offset := 0.0
@export var piece_scale := Vector2.ONE
@export var layer := 4

func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = offset
	sprite.rotation = rotation_offset
	sprite.scale = piece_scale
	add_child(sprite)
	z_index = layer

