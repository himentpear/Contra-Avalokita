extends Node

signal boss_defeated(boss_id: StringName, source_character: StringName)
signal character_unlocked(character_id: StringName)
signal world_state_changed(key: StringName, value: Variant)
signal run_started(character_id: StringName, seed: int)
signal run_ended(character_id: StringName, result: Dictionary)
signal content_registered(content_id: StringName)
signal save_loaded(campaign_id: StringName)
signal save_requested(campaign_id: StringName)
