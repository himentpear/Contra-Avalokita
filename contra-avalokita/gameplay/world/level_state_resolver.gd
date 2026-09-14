class_name LevelStateResolver
extends RefCounted

static func resolve(base_state: Dictionary, world_state: Dictionary, character_state: Dictionary, event_ledger: Array) -> Dictionary:
	var result := base_state.duplicate(true)
	result["world"] = world_state.duplicate(true)
	result["character"] = character_state.duplicate(true)
	result["events"] = event_ledger.duplicate(true)
	return result

static func boss_exists(world_state: Dictionary, boss_id: StringName) -> bool:
	return String(world_state.get("bosses", {}).get(String(boss_id), "alive")) != "dead"

static func flag_enabled(world_state: Dictionary, flag: StringName) -> bool:
	return bool(world_state.get("flags", {}).get(String(flag), false))

