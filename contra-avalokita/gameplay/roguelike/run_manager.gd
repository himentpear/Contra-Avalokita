class_name RunManager
extends Node

signal run_started(state: RunState)
signal run_ended(result: Dictionary)

const ScoreSystemScript := preload("res://gameplay/roguelike/scoring/score_system.gd")
var active_run: RunState
var character_state: Dictionary = {}
var seed_manager := SeedManager.new()
var score_system: Node

func _ready() -> void:
	score_system = ScoreSystemScript.new()
	score_system.name = "ScoreSystem"
	add_child(score_system)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.save_requested.connect(_on_save_requested)

func start_run(seed: int, character_id: StringName) -> RunState:
	seed_manager.configure(seed)
	active_run = RunState.new()
	active_run.seed = seed
	score_system.reset_run()
	snapshot_to_character_state()
	run_started.emit(active_run)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.run_started.emit(character_id, seed)
	return active_run

func end_run(character_id: StringName, result: Dictionary = {}) -> void:
	if active_run != null:
		active_run.run_score = score_system.total
	if not character_state.is_empty():
		character_state["active_run"] = {}
	run_ended.emit(result)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.run_ended.emit(character_id, result)
	active_run = null

func bind_character_state(value: Dictionary) -> void:
	character_state = value
	var saved_run: Dictionary = character_state.get("active_run", {})
	active_run = RunState.from_dictionary(saved_run) if not saved_run.is_empty() else null
	if active_run != null:
		seed_manager.configure(active_run.seed)
		score_system.total = active_run.run_score

func snapshot_to_character_state() -> void:
	if character_state.is_empty():
		return
	if active_run == null:
		character_state["active_run"] = {}
		return
	active_run.run_score = score_system.total
	character_state["active_run"] = active_run.to_dictionary()

func _on_save_requested(_campaign_id: StringName) -> void:
	snapshot_to_character_state()

