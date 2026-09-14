class_name SaveSchema
extends RefCounted

const CURRENT_VERSION := 1

static func new_account() -> Dictionary:
	return {"schema_version": CURRENT_VERSION, "settings": {}, "global_codex": [], "achievements": [], "global_statistics": {}}

static func new_campaign(campaign_id: StringName, game_version: String, packages: Dictionary) -> Dictionary:
	return {
		"schema_version": CURRENT_VERSION,
		"game_version": game_version,
		"campaign_id": String(campaign_id),
		"packages": packages.duplicate(true),
		"meta": {"created_at": Time.get_unix_time_from_system(), "last_played_at": Time.get_unix_time_from_system()},
		"world_state": {"bosses": {}, "npcs": {}, "levels": {}, "flags": {}, "global_unlocks": [], "events": []},
		"characters": {}
	}

static func new_character(character_id: StringName) -> Dictionary:
	return {"character_id": String(character_id), "position": {}, "checkpoint": "", "character_story_flags": {}, "skills": [], "equipment": [], "weapons": [], "character_karma": 0, "character_unlocks": [], "persistent_stats": {}, "active_run": {}}

static func new_run(seed: int) -> Dictionary:
	return {"seed": seed, "current_level": "", "current_room": "", "hp": 0.0, "temporary_stats": {}, "loot": [], "morphs": [], "temporary_build": {}, "run_score": 0, "run_events": []}

static func new_world_event(event_id: StringName, event_type: StringName, source_character: StringName, target: StringName, metadata: Dictionary = {}) -> Dictionary:
	return {"event_id": String(event_id), "event_type": String(event_type), "source_character": String(source_character), "target": String(target), "world_time": Time.get_unix_time_from_system(), "metadata": metadata.duplicate(true)}

