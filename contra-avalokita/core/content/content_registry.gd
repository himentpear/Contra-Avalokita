extends Node

const ID_PATTERN := "^[a-z][a-z0-9_]*:[a-z][a-z0-9_./-]*$"
var _content: Dictionary = {}
var _packages: Dictionary = {}
var _id_regex := RegEx.new()

func _ready() -> void:
	_id_regex.compile(ID_PATTERN)

func clear() -> void:
	_content.clear()
	_packages.clear()

func register_manifest(manifest: ContentManifest) -> Error:
	if manifest == null or not _valid_namespace(manifest.id):
		return ERR_INVALID_DATA
	if manifest.content_type == "mod" and manifest.id in [&"base", &"core"]:
		return ERR_UNAUTHORIZED
	if _packages.has(manifest.id):
		return ERR_ALREADY_EXISTS
	for definition in manifest.definitions:
		if not _valid_definition(definition) or get_namespace(definition.id) != manifest.id:
			return ERR_INVALID_DATA
		if _content.has(definition.id):
			return ERR_ALREADY_EXISTS
	_packages[manifest.id] = manifest
	for definition in manifest.definitions:
		_content[definition.id] = definition
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").content_registered.emit(definition.id)
	return OK

func register_content(definition: ContentDefinition) -> Error:
	if not _valid_definition(definition):
		return ERR_INVALID_DATA
	if _content.has(definition.id):
		return ERR_ALREADY_EXISTS
	_content[definition.id] = definition
	return OK

func unregister_namespace(namespace_id: StringName) -> void:
	for content_id in _content.keys():
		if get_namespace(content_id) == namespace_id:
			_content.erase(content_id)
	_packages.erase(namespace_id)

func get_content(id: StringName) -> ContentDefinition:
	return _content.get(id) as ContentDefinition

func has_content(id: StringName) -> bool:
	return _content.has(id)

func query(content_type: StringName) -> Array[ContentDefinition]:
	var result: Array[ContentDefinition] = []
	for definition: ContentDefinition in _content.values():
		if definition.content_type == content_type:
			result.append(definition)
	return result

func query_by_tag(content_type: StringName, tags: Array[StringName]) -> Array[ContentDefinition]:
	var result: Array[ContentDefinition] = []
	for definition in query(content_type):
		var matches := true
		for tag in tags:
			if not definition.tags.has(tag):
				matches = false
				break
		if matches:
			result.append(definition)
	return result

func get_namespace(id: StringName) -> StringName:
	return StringName(String(id).get_slice(":", 0)) if String(id).contains(":") else &""

func list_namespaces() -> Array[StringName]:
	var result: Array[StringName] = []
	for namespace_id: StringName in _packages.keys():
		result.append(namespace_id)
	result.sort()
	return result

func list_packages() -> Dictionary:
	var result: Dictionary = {}
	for namespace_id: StringName in _packages:
		var manifest: ContentManifest = _packages[namespace_id]
		result[String(namespace_id)] = manifest.version
	return result

func _valid_id(id: StringName) -> bool:
	return _id_regex.search(String(id)) != null

func _valid_namespace(namespace_id: StringName) -> bool:
	var text := String(namespace_id)
	return not text.is_empty() and not text.contains(":") and _id_regex.search(text + ":item") != null

func _valid_definition(definition: ContentDefinition) -> bool:
	if definition == null or not _valid_id(definition.id) or definition.content_type.is_empty():
		return false
	return definition.resource != null or bool(definition.metadata.get("data_only", false))
