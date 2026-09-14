extends Node

signal campaign_created(campaign_id: StringName)
signal campaign_loaded(campaign_id: StringName)
signal campaign_saved(campaign_id: StringName)

const SAVE_DIR := "user://saves"
const ACCOUNT_PATH := "user://account.json"
var account: Dictionary = {}
var active_campaign: Dictionary = {}

func initialize() -> Error:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	if error != OK:
		return error
	account = SaveSerializer.read_json(ACCOUNT_PATH)
	if account.is_empty():
		account = SaveSchema.new_account()
	else:
		account = SaveMigrator.migrate(account)
	return OK

func save_account() -> Error:
	return SaveSerializer.write_json(ACCOUNT_PATH, account)

func list_campaigns() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(SAVE_DIR)
	if directory == null:
		return result
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() != "json":
			continue
		var data := SaveSerializer.read_json(SAVE_DIR.path_join(file_name))
		if not data.is_empty():
			result.append({"campaign_id": data.get("campaign_id", file_name.get_basename()), "game_version": data.get("game_version", "unknown"), "schema_version": data.get("schema_version", 0), "meta": data.get("meta", {})})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.campaign_id) < String(b.campaign_id))
	return result

func create_campaign(campaign_id: StringName) -> Dictionary:
	if not _valid_campaign_id(campaign_id):
		return {}
	var packages: Dictionary = ContentRegistry.list_packages() if has_node("/root/ContentRegistry") else {}
	active_campaign = SaveSchema.new_campaign(campaign_id, GameVersion.VERSION, packages)
	campaign_created.emit(campaign_id)
	return active_campaign

func load_campaign(campaign_id: StringName) -> Error:
	if not _valid_campaign_id(campaign_id):
		return ERR_INVALID_PARAMETER
	var data := SaveSerializer.read_json(_campaign_path(campaign_id))
	if data.is_empty():
		return ERR_FILE_NOT_FOUND
	data = SaveMigrator.migrate(data)
	if data.is_empty():
		return ERR_INVALID_DATA
	active_campaign = data
	campaign_loaded.emit(campaign_id)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").save_loaded.emit(campaign_id)
	return OK

func save_active_campaign() -> Error:
	if active_campaign.is_empty():
		return ERR_DOES_NOT_EXIST
	active_campaign.meta.last_played_at = Time.get_unix_time_from_system()
	var campaign_id := StringName(active_campaign.campaign_id)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").save_requested.emit(campaign_id)
	var error := SaveSerializer.write_json(_campaign_path(campaign_id), active_campaign)
	if error == OK:
		campaign_saved.emit(campaign_id)
	return error

func ensure_character(character_id: StringName) -> Dictionary:
	if active_campaign.is_empty():
		return {}
	var key := String(character_id)
	if not active_campaign.characters.has(key):
		active_campaign.characters[key] = SaveSchema.new_character(character_id)
	return active_campaign.characters[key]

func append_world_event(event_type: StringName, source_character: StringName, target: StringName, metadata: Dictionary = {}) -> Dictionary:
	if active_campaign.is_empty():
		return {}
	var ledger: Array = active_campaign.world_state.events
	var event_id := StringName("event_%d" % (ledger.size() + 1))
	var event := SaveSchema.new_world_event(event_id, event_type, source_character, target, metadata)
	ledger.append(event)
	return event

func resolve_content_reference(content_id: StringName) -> Variant:
	var definition: ContentDefinition = ContentRegistry.get_content(content_id) if has_node("/root/ContentRegistry") else null
	if definition != null:
		return definition
	return {"missing_content": true, "content_id": String(content_id), "namespace": String(ContentRegistry.get_namespace(content_id))}

func get_info() -> Dictionary:
	if active_campaign.is_empty():
		return {"active": false}
	return {"active": true, "campaign_id": active_campaign.campaign_id, "schema_version": active_campaign.schema_version, "game_version": active_campaign.game_version, "packages": active_campaign.packages, "characters": active_campaign.characters.keys(), "world_events": active_campaign.world_state.events.size()}

func find_missing_content_references(value: Variant = null) -> Dictionary:
	var missing: Dictionary = {}
	_scan_content_references(active_campaign if value == null else value, missing)
	return missing

func _scan_content_references(value: Variant, missing: Dictionary) -> void:
	if value is String or value is StringName:
		var candidate := StringName(value)
		if String(candidate).contains(":") and not ContentRegistry.has_content(candidate):
			var namespace_id := String(ContentRegistry.get_namespace(candidate))
			if not missing.has(namespace_id):
				missing[namespace_id] = []
			if not missing[namespace_id].has(String(candidate)):
				missing[namespace_id].append(String(candidate))
	elif value is Dictionary:
		for child: Variant in value.values():
			_scan_content_references(child, missing)
	elif value is Array:
		for child: Variant in value:
			_scan_content_references(child, missing)

func _campaign_path(campaign_id: StringName) -> String:
	return "%s/%s.json" % [SAVE_DIR, String(campaign_id)]

func _valid_campaign_id(campaign_id: StringName) -> bool:
	var value := String(campaign_id)
	return not value.is_empty() and value.is_valid_filename() and value == value.to_snake_case()
