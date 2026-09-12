class_name SdfMorphProfile
extends Resource
## Stackable roguelike body mutation data. Armor and weapons are intentionally
## absent: profiles only change the living mud SDF.

const SdfModifier = preload("res://scripts/sdf_modifier.gd")

@export var id: StringName = &"Morph"
@export var modifiers: Array[SdfModifier] = []
@export_range(0.25, 3.0, 0.01) var head_radius_multiplier := 1.0
@export_range(0.25, 3.0, 0.01) var body_radius_multiplier := 1.0
@export_range(0.25, 3.0, 0.01) var arm_radius_multiplier := 1.0
@export_range(0.25, 3.0, 0.01) var leg_radius_multiplier := 1.0
@export var mud_color_override_enabled := false
@export var mud_color := Color.WHITE
