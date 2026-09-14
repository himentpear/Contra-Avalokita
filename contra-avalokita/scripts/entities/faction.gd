class_name Faction
extends RefCounted

enum Type {
	NEUTRAL = 0,
	PLAYER = 1,
	ENEMY = 2,
	ENVIRONMENT = 3,
}

static func is_hostile(source_type: int, target_type: int) -> bool:
	if source_type == Type.NEUTRAL or target_type == Type.NEUTRAL:
		return false
	if source_type == Type.ENVIRONMENT or target_type == Type.ENVIRONMENT:
		return true
	return source_type != target_type

static func get_faction_of(entity: Node) -> int:
	if not is_instance_valid(entity):
		return Type.NEUTRAL
	if entity.has_meta("faction"):
		return int(entity.get_meta("faction"))
	if entity.is_in_group(&"player_input_entities") or entity.is_in_group(&"player"):
		return Type.PLAYER
	if entity.is_in_group(&"enemies") or entity.name.begins_with("Enemy"):
		return Type.ENEMY
	if entity.name.begins_with("Dummy") or entity.name.begins_with("TestDummy") or entity.name.begins_with("TrainingDummy"):
		return Type.ENEMY
	return Type.NEUTRAL
