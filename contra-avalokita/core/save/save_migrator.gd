class_name SaveMigrator
extends RefCounted

static func migrate(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	var version := int(migrated.get("schema_version", 0))
	while version < SaveSchema.CURRENT_VERSION:
		match version:
			0:
				migrated = _migrate_0_to_1(migrated)
			_:
				push_error("No save migration from schema %d" % version)
				return {}
		version = int(migrated.get("schema_version", version))
	return migrated

static func _migrate_0_to_1(data: Dictionary) -> Dictionary:
	data["schema_version"] = 1
	if not data.has("packages"):
		data["packages"] = {}
	if not data.has("world_state"):
		data["world_state"] = {"bosses": {}, "npcs": {}, "levels": {}, "flags": {}, "global_unlocks": [], "events": []}
	if not data.has("characters"):
		data["characters"] = {}
	return data

