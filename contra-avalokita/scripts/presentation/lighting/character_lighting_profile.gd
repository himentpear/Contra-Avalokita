class_name CharacterLightingProfile
extends Resource

## Visual configuration resource defining 2D character lighting parameters.
## Reusable across multiple characters and completely decoupled from gameplay state.

@export_category("Masks")
@export_flags_2d_render var actor_light_mask: int = 8
@export_flags_2d_render var emissive_light_mask: int = 32

@export_category("Body Lighting")
@export_range(0.0, 1.0) var minimum_ambient: float = 0.55
@export_range(0.0, 1.5) var mid_level: float = 0.82
@export_range(0.0, 2.0) var key_level: float = 1.10
@export var shadow_color: Color = Color(0.40, 0.45, 0.52, 1.0)
@export var mid_color: Color = Color.WHITE
@export var key_color: Color = Color.WHITE

@export_category("Rim Light")
@export_range(0.0, 2.0) var rim_strength: float = 0.35
@export_range(0.0, 1.0) var rim_width: float = 0.12
@export_range(0.0, 3.0) var rim_max_energy: float = 1.5

@export_category("Equipment")
@export_range(0.0, 3.0) var weapon_highlight_strength: float = 1.4
@export_range(0.0, 1.0) var metal_highlight_width: float = 0.08

@export_category("Response")
@export_range(1.0, 40.0) var light_response_speed: float = 12.0
@export_range(0.0, 2.0) var hit_flash_strength: float = 1.0

@export_category("Ground Shadow")
@export var ground_shadow_enabled: bool = false
@export var ground_shadow_base_scale: Vector2 = Vector2(1.0, 0.28)
@export_range(0.0, 1.0) var ground_shadow_base_alpha: float = 0.55
@export_range(10.0, 300.0) var ground_shadow_max_distance: float = 120.0
