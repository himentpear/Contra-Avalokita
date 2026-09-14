class_name PackageLoader
extends RefCounted

const BASE_MANIFEST := "res://content/base/manifest.tres"

func mount_packages(include_test_packages := true) -> Array:
	var manifests: Array = []
	_mount_pcks("dlc")
	_mount_pcks("mods")
	var base := load(BASE_MANIFEST) as ContentManifest
	if base != null:
		manifests.append(base)
	_discover_manifests("res://extensions/dlc", manifests, include_test_packages)
	manifests.append_array(DataModLoader.new().load_manifests())
	return manifests

func _mount_pcks(subdirectory: String) -> void:
	var directory_path := "user://%s" % subdirectory
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.get_extension().to_lower() == "pck":
			ProjectSettings.load_resource_pack(directory_path.path_join(filename), false)

func _discover_manifests(path: String, manifests: Array, include_test_packages := true) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child in directory.get_directories():
		var manifest_path := path.path_join(child).path_join("manifest.tres")
		if not include_test_packages and child.to_lower().begins_with("test"):
			continue
		if ResourceLoader.exists(manifest_path):
			var manifest := load(manifest_path) as ContentManifest
			if manifest != null:
				manifests.append(manifest)
