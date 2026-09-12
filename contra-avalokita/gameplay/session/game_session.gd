class_name GameSession
extends Node

var world_manager: WorldManager
var run_manager: RunManager
var combat_context: CombatContext
var player: Node
var current_character_id: StringName

func _ready() -> void:
	world_manager = WorldManager.new()
	world_manager.name = "WorldManager"
	add_child(world_manager)
	run_manager = RunManager.new()
	run_manager.name = "RunManager"
	add_child(run_manager)
	combat_context = CombatContext.new()
	combat_context.name = "CombatContext"
	add_child(combat_context)
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		save_manager.campaign_created.connect(_on_campaign_changed)
		save_manager.campaign_loaded.connect(_on_campaign_changed)
		if not save_manager.active_campaign.is_empty():
			bind_campaign(save_manager.active_campaign)

func set_player(value: Node) -> void:
	if is_instance_valid(player):
		combat_context.unregister_actor(player)
	player = value
	if is_instance_valid(player):
		combat_context.register_actor(player)

func get_score_system() -> Node:
	return run_manager.score_system if is_instance_valid(run_manager) else null

func bind_campaign(campaign: Dictionary) -> void:
	world_manager.bind_campaign(campaign)
	if not current_character_id.is_empty():
		activate_character(current_character_id)

func activate_character(character_id: StringName) -> Dictionary:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null or save_manager.active_campaign.is_empty():
		return {}
	current_character_id = character_id
	var character_state: Dictionary = save_manager.ensure_character(character_id)
	run_manager.bind_character_state(character_state)
	return character_state

func _on_campaign_changed(_campaign_id: StringName) -> void:
	current_character_id = &""
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		bind_campaign(save_manager.active_campaign)
