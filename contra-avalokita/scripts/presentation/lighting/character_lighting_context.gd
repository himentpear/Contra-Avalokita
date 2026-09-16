class_name CharacterLightingContext
extends RefCounted

## Pure semantic data container for 2D character lighting evaluation.
## Decoupled from any concrete character, node hierarchy, or gameplay logic.

var world_position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var grounded: bool = true
var facing: float = 1.0
var ground_distance: float = 0.0

var key_direction: Vector2 = Vector2(0.0, -1.0)
var key_color: Color = Color.WHITE
var key_energy: float = 1.0

var ambient_color: Color = Color(0.55, 0.55, 0.55, 1.0)

var hit_flash: float = 0.0
var status_tint: Color = Color(0.0, 0.0, 0.0, 0.0)
var dissolve_amount: float = 0.0
var emissive_dissolve: float = 0.0
