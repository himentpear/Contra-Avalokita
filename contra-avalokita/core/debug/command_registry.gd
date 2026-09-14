extends Node

signal command_executed(command: StringName, result: Variant)

var _commands: Dictionary = {}

func _ready() -> void:
	register_command(&"help", Callable(self, "_help"), "List available commands")
	register_command(&"content.list", Callable(self, "_content_list"), "List registered content")
	register_command(&"content.info", Callable(self, "_content_info"), "Show a content definition")
	register_command(&"give", Callable(self, "_give"), "Equip content by stable ID")
	register_command(&"save.info", Callable(self, "_save_info"), "Show active campaign information")
	register_command(&"save.force", Callable(self, "_save_force"), "Save the active campaign")
	register_command(&"sdf.show", Callable(self, "_sdf_show"), "Toggle character SDF debug view")
	register_command(&"sdf.morph", Callable(self, "_sdf_morph"), "Apply a morph profile: sdf.morph <id>")
	register_command(&"sdf.clear", Callable(self, "_sdf_clear"), "Clear applied morph profiles")
	register_command(&"mod.list", Callable(self, "_mod_list"), "List installed content packages and versions")
	register_command(&"perf.fps", Callable(self, "_perf_fps"), "Display current FPS and frame time")
	register_command(&"god", Callable(self, "_god"), "Toggle god mode on player")
	register_command(&"damage", Callable(self, "_damage"), "Deal damage to player: damage <amount>")
	register_command(&"kill", Callable(self, "_kill"), "Kill player instantly")
	register_command(&"run.seed", Callable(self, "_run_seed"), "Get or set run seed")

func register_command(name: StringName, callable: Callable, description: String = "") -> Error:
	if name.is_empty() or not callable.is_valid():
		return ERR_INVALID_PARAMETER
	if _commands.has(name):
		return ERR_ALREADY_EXISTS
	_commands[name] = {"callable": callable, "description": description}
	return OK

func unregister_command(name: StringName) -> void:
	_commands.erase(name)

func execute(text: String) -> Variant:
	var tokens := text.strip_edges().split(" ", false)
	if tokens.is_empty():
		return ""
	var name := StringName(tokens[0])
	if not _commands.has(name):
		return "Unknown command: %s" % name
	var args := Array(tokens.slice(1))
	var result: Variant = (_commands[name].callable as Callable).call(args)
	command_executed.emit(name, result)
	return result

func get_suggestions(prefix: String) -> PackedStringArray:
	var result := PackedStringArray()
	for name: StringName in _commands:
		if String(name).begins_with(prefix):
			result.append(String(name))
	result.sort()
	return result

func _help(_args: Array) -> String:
	var lines := PackedStringArray()
	for name in get_suggestions(""):
		lines.append("%-16s %s" % [name, _commands[StringName(name)].description])
	return "\n".join(lines)

func _content_list(args: Array) -> String:
	var type := StringName(args[0]) if not args.is_empty() else &""
	var definitions: Array[ContentDefinition] = ContentRegistry.query(type) if not type.is_empty() else ContentRegistry.query(&"weapon")
	var ids := PackedStringArray()
	for definition in definitions:
		ids.append(String(definition.id))
	return "\n".join(ids) if not ids.is_empty() else "No matching content"

func _content_info(args: Array) -> Variant:
	if args.is_empty():
		return "Usage: content.info namespace:item"
	var definition: ContentDefinition = ContentRegistry.get_content(StringName(args[0]))
	if definition == null:
		return "Missing content: %s" % args[0]
	return {"id": definition.id, "type": definition.content_type, "display_name": definition.display_name, "tags": definition.tags, "resource": definition.resource.resource_path}

func _save_info(_args: Array) -> Dictionary:
	var info: Dictionary = SaveManager.get_info()
	info["missing_content"] = SaveManager.find_missing_content_references()
	return info

func _give(args: Array) -> String:
	if args.is_empty():
		return "Usage: give namespace:item"
	var definition: ContentDefinition = ContentRegistry.get_content(StringName(args[0]))
	if definition == null or definition.content_type != &"weapon" or not definition.resource is PackedScene:
		return "Content is missing or not an equippable weapon: %s" % args[0]
	var scene := get_tree().current_scene
	var player: Node = scene.get("player") if scene != null else null
	if not is_instance_valid(player) or player.get("weapons") == null:
		return "No active player"
	player.weapons.equip(definition.resource as PackedScene)
	return "Equipped %s" % definition.id

func _save_force(_args: Array) -> String:
	return error_string(SaveManager.save_active_campaign())

func _sdf_show(_args: Array) -> String:
	var scene := get_tree().current_scene
	var player: Node = scene.get("player") if scene != null else null
	if is_instance_valid(player) and player.get("rig") != null:
		player.rig.debug_draw = not player.rig.debug_draw
		return "SDF debug: %s" % player.rig.debug_draw
	return "No active character"

func _sdf_morph(args: Array) -> String:
	if args.is_empty():
		return "Usage: sdf.morph namespace:morph"
	var definition: ContentDefinition = ContentRegistry.get_content(StringName(args[0]))
	if definition == null or definition.content_type != &"morph" or not definition.resource is SdfMorphProfile:
		return "Not a valid morph profile: %s" % args[0]
	var scene := get_tree().current_scene
	var player: Node = scene.get("player") if scene != null else null
	if is_instance_valid(player) and player.get("body_renderer") != null:
		player.body_renderer.apply_morph_profile(definition.resource as SdfMorphProfile)
		player.body_renderer.sync_skeleton(player.skeleton)
		return "Applied morph: %s" % definition.id
	return "No active character"

func _sdf_clear(_args: Array) -> String:
	var scene := get_tree().current_scene
	var player: Node = scene.get("player") if scene != null else null
	if is_instance_valid(player) and player.get("body_renderer") != null:
		player.body_renderer.clear_morph_profiles()
		player.body_renderer.sync_skeleton(player.skeleton)
		return "Cleared all active morphs"
	return "No active character"

func _mod_list(_args: Array) -> Dictionary:
	return ContentRegistry.list_packages()

func _perf_fps(_args: Array) -> String:
	var fps := Engine.get_frames_per_second()
	return "FPS: %d (Frame Time: %.2f ms)" % [fps, 1000.0 / maxf(float(fps), 1.0)]

func _god(_args: Array) -> String:
	var scene := get_tree().current_scene
	var player: Node = scene.get("player") if scene != null else null
	if is_instance_valid(player):
		var current_god: bool = bool(player.get("god_mode"))
		player.set("god_mode", not current_god)
		return "God mode: %s" % str(not current_god)
	return "No active player"

func _damage(args: Array) -> String:
	var amount := float(args[0]) if not args.is_empty() else 25.0
	var scene := get_tree().current_scene
	var player: Node = scene.get("player") if scene != null else null
	if is_instance_valid(player) and player.has_method("receive_hit"):
		player.receive_hit(amount)
		return "Dealt %.1f damage" % amount
	return "No active player"

func _kill(_args: Array) -> String:
	var scene := get_tree().current_scene
	var player: Node = scene.get("player") if scene != null else null
	if is_instance_valid(player) and player.has_method("receive_hit"):
		player.receive_hit(99999.0)
		return "Executed lethal strike on player"
	return "No active player"

func _run_seed(args: Array) -> String:
	var session: Node = Game.current_session if Game != null else null
	if session != null and session.get("run_manager") != null:
		var run_manager = session.get("run_manager")
		if not args.is_empty():
			var new_seed := int(args[0])
			run_manager.start_run(new_seed)
			return "Started run with seed %d" % new_seed
		elif run_manager.current_run != null:
			return "Current run seed: %d" % run_manager.current_run.seed
	return "No active run"
