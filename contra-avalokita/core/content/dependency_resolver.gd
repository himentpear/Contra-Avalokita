class_name DependencyResolver
extends RefCounted

static func resolve(manifests: Array) -> Dictionary:
	var by_id: Dictionary = {}
	for manifest in manifests:
		if manifest == null or manifest.id.is_empty():
			return {"ok": false, "error": "Invalid manifest", "ordered": []}
		if by_id.has(manifest.id):
			return {"ok": false, "error": "Duplicate package: %s" % manifest.id, "ordered": []}
		by_id[manifest.id] = manifest
	var visiting: Dictionary = {}
	var visited: Dictionary = {}
	var ordered: Array = []
	for manifest in manifests:
		var error := _visit(manifest, by_id, visiting, visited, ordered)
		if not error.is_empty():
			return {"ok": false, "error": error, "ordered": []}
	return {"ok": true, "error": "", "ordered": ordered}

static func _visit(manifest: ContentManifest, by_id: Dictionary, visiting: Dictionary, visited: Dictionary, ordered: Array) -> String:
	if visited.has(manifest.id):
		return ""
	if visiting.has(manifest.id):
		return "Circular package dependency at %s" % manifest.id
	visiting[manifest.id] = true
	for dependency in manifest.dependencies:
		var dependency_id := StringName(dependency.get_slice("@", 0))
		if not by_id.has(dependency_id):
			return "Missing package dependency %s required by %s" % [dependency_id, manifest.id]
		var error := _visit(by_id[dependency_id], by_id, visiting, visited, ordered)
		if not error.is_empty():
			return error
	visiting.erase(manifest.id)
	visited[manifest.id] = true
	ordered.append(manifest)
	return ""
