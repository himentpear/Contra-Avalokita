class_name Damageable
extends Node

const Faction = preload("res://scripts/entities/faction.gd")
const HitEvent = preload("res://scripts/hit_event.gd")
const HitData = preload("res://scripts/combat/hit_data.gd")

signal hit_received(event: HitData)
signal damaged(amount: float, event: HitData)
signal healed(amount: float)
signal died(event: HitData)
signal poise_broken(event: HitData)

@export var faction_type: int = Faction.Type.NEUTRAL
@export var invulnerable: bool = false
@export var owner_actor: Node = null

func _ready() -> void:
	if not owner_actor:
		owner_actor = get_parent()

func setup(p_owner: Node, p_faction: int = Faction.Type.NEUTRAL) -> void:
	owner_actor = p_owner
	faction_type = p_faction

func can_be_damaged_by(attacker: Node) -> bool:
	if invulnerable:
		return false
	if not is_instance_valid(attacker):
		return true
	var attacker_faction: int = Faction.get_faction_of(attacker)
	return Faction.is_hostile(attacker_faction, faction_type)
