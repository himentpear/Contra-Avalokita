class_name IntentComponent
extends Resource

## Pure input intent data. Systems write this component; gameplay continues to
## consume the legacy MudCharacter.set_intent() seam during ECS phase 1.
@export_range(-1.0, 1.0, 0.01) var move_direction := 0.0
@export var sprint_held := false
@export var jump_pressed := false
@export var attack_pressed := false
@export var block_held := false

## Transitional action intents. Their existing equipment, weapon and debug
## handlers remain unchanged and are invoked by PlayerInputSystem.
@export var equipment_toggle_pressed := false
@export var equip_sword_pressed := false
@export var unequip_weapon_pressed := false
@export var debug_rig_pressed := false
