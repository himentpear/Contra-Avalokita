class_name WorldManager
extends Node

signal state_changed(key: StringName, value: Variant)
var world_state: Dictionary = {}
var event_ledger: Array = []

func bind_campaign(campaign: Dictionary) -> void:
	world_state = campaign.get("world_state", {})
	event_ledger = world_state.get("events", [])

func set_world_flag(key: StringName, value: Variant, source_character: StringName = &"") -> void:
	if not world_state.has("flags"):
		world_state["flags"] = {}
	world_state.flags[String(key)] = value
	state_changed.emit(key, value)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.world_state_changed.emit(key, value)
	if not source_character.is_empty():
		var save_manager := get_node_or_null("/root/SaveManager")
		if save_manager != null:
			save_manager.append_world_event(&"world_flag_changed", source_character, key, {"value": value})

