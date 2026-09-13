class_name HitData
extends RefCounted

## Function-driven description of a confirmed hit. Weapons describe the hit here;
## HitstopManager remains the only place that converts it into stop durations.
var attacker: Node
var victim: Node

var damage: float = 0.0
var impact: float = 1.0
var weapon_type: StringName = &"slash"

var is_critical: bool = false
var is_kill: bool = false
var is_armor_break: bool = false
var is_parry: bool = false
var is_blocked: bool = false
var hit_index: int = 0

## Compatibility alias for the project's pre-existing impact field.
var impact_strength: float:
	get:
		return impact
	set(value):
		impact = value

## These are reserved for cinematic/manual requests, never ordinary weapons.
var attacker_stop_override: float = -1.0
var victim_stop_override: float = -1.0
var world_stop_override: float = -1.0
var bypass_frequency_decay: bool = false
