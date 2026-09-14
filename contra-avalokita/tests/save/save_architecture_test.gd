extends Node

var campaign_a_id: StringName
var campaign_b_id: StringName

func _ready() -> void:
	var timestamp := Time.get_ticks_usec()
	campaign_a_id = StringName("_architecture_test_a_%d" % timestamp)
	campaign_b_id = StringName("_architecture_test_b_%d" % timestamp)
	assert(SaveManager.initialize() == OK)
	Game.start_session(GameSession.new())
	await get_tree().process_frame

	var campaign_a := SaveManager.create_campaign(campaign_a_id)
	assert(not campaign_a.is_empty())
	var mud: Dictionary = Game.current_session.activate_character(&"base:mud_monkey")
	var mulian: Dictionary = SaveManager.ensure_character(&"base:mulian")
	mud.skills.append("base:test_skill")
	Game.current_session.world_manager.set_world_flag(&"tengu_dead", true, &"base:mud_monkey")
	var run: RunState = Game.current_session.run_manager.start_run(424242, &"base:mud_monkey")
	run.current_level = &"base:test_level"
	run.hp = 17.0
	Game.current_session.get_score_system().total = 99
	assert(SaveManager.save_active_campaign() == OK)

	var campaign_b := SaveManager.create_campaign(campaign_b_id)
	assert(not campaign_b.world_state.flags.has("tengu_dead"))
	assert(campaign_b.characters.is_empty())
	assert(SaveManager.save_active_campaign() == OK)

	assert(SaveManager.load_campaign(campaign_a_id) == OK)
	assert(SaveManager.active_campaign.world_state.flags.tengu_dead)
	assert(SaveManager.active_campaign.characters.has("base:mud_monkey"))
	assert(SaveManager.active_campaign.characters.has("base:mulian"))
	assert(mud != mulian)
	var restored: Dictionary = Game.current_session.activate_character(&"base:mud_monkey")
	assert(restored.active_run.seed == 424242)
	assert(restored.active_run.hp == 17.0)
	assert(restored.active_run.run_score == 99)
	assert(SaveManager.active_campaign.world_state.events[0].source_character == "base:mud_monkey")
	var missing := SaveManager.find_missing_content_references()
	assert(missing.has("base"))
	assert(missing.base.has("base:test_skill"))

	_cleanup_campaign(campaign_a_id)
	_cleanup_campaign(campaign_b_id)
	print("SAVE_ARCHITECTURE_OK")
	get_tree().quit()

func _cleanup_campaign(campaign_id: StringName) -> void:
	var path := ProjectSettings.globalize_path("user://saves/%s.json" % campaign_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
