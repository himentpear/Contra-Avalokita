class_name RunState
extends Resource

@export var seed: int
@export var current_level: StringName
@export var current_room: StringName
@export var hp: float
@export var temporary_stats: Dictionary = {}
@export var loot: Array[StringName] = []
@export var morphs: Array[StringName] = []
@export var temporary_build: Dictionary = {}
@export var run_score: int
@export var run_events: Array[Dictionary] = []

func to_dictionary() -> Dictionary:
	return {"seed": seed, "current_level": String(current_level), "current_room": String(current_room), "hp": hp, "temporary_stats": temporary_stats.duplicate(true), "loot": Array(loot), "morphs": Array(morphs), "temporary_build": temporary_build.duplicate(true), "run_score": run_score, "run_events": run_events.duplicate(true)}

static func from_dictionary(data: Dictionary) -> RunState:
	var state := RunState.new()
	state.seed = int(data.get("seed", 0))
	state.current_level = StringName(data.get("current_level", ""))
	state.current_room = StringName(data.get("current_room", ""))
	state.hp = float(data.get("hp", 0.0))
	state.temporary_stats = data.get("temporary_stats", {}).duplicate(true)
	for id: Variant in data.get("loot", []):
		state.loot.append(StringName(id))
	for id: Variant in data.get("morphs", []):
		state.morphs.append(StringName(id))
	state.temporary_build = data.get("temporary_build", {}).duplicate(true)
	state.run_events.clear()
	for ev: Variant in data.get("run_events", []):
		if ev is Dictionary:
			state.run_events.append((ev as Dictionary).duplicate(true))
	return state

