@tool
class_name RotoBoneWorkspace
extends RefCounted

signal template_status_changed(ready: bool, message: String)
signal profile_changed(profile: RotoBoneAnimationProfile)
signal time_changed(time: float)

const CATALOG_PATH := "res://addons/rotobone/v3/animation/animation_catalog.json"
const Adapter := preload("res://addons/rotobone/v3/core/mud_character_adapter.gd")
const Profile := preload("res://addons/rotobone/v3/animation/animation_profile.gd")

var adapter := Adapter.new()
var profiles: Array[RotoBoneAnimationProfile] = []
var active_profile: RotoBoneAnimationProfile
var current_time := 0.0


func initialize(scene_root: Node = null) -> bool:
	load_catalog()
	var ready := adapter.bind_from_edited_scene(scene_root) if scene_root != null else adapter.load_template()
	var message := "Mud Character · template detected" if ready else "Mud Character · open the v3 test scene"
	template_status_changed.emit(ready, message)
	if ready and active_profile != null:
		_sync_profile_duration(active_profile)
	return ready


func load_catalog(path := CATALOG_PATH) -> Error:
	profiles.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return ERR_PARSE_ERROR
	for entry in data.get("animations", []):
		if entry is Dictionary:
			profiles.append(Profile.from_dictionary(entry))
	if not profiles.is_empty():
		active_profile = profiles[0]
	return OK


func select_profile(index: int) -> void:
	if index < 0 or index >= profiles.size():
		return
	active_profile = profiles[index]
	_sync_profile_duration(active_profile)
	set_time(minf(current_time, active_profile.duration))
	profile_changed.emit(active_profile)


func set_time(value: float) -> void:
	var maximum := active_profile.duration if active_profile != null else 60.0
	current_time = clampf(value, 0.0, maximum)
	if adapter.animation_player != null and active_profile != null:
		var source := active_profile.source_animation
		if adapter.animation_player.has_animation(source):
			adapter.animation_player.play(source)
			adapter.animation_player.seek(current_time, true)
			adapter.animation_player.pause()
	time_changed.emit(current_time)


func add_marker(marker: RotoBoneKeyframeMarker) -> void:
	if active_profile == null:
		return
	marker.time = current_time
	active_profile.add_marker(marker)
	profile_changed.emit(active_profile)


func _sync_profile_duration(profile: RotoBoneAnimationProfile) -> void:
	if adapter.animation_player == null or not adapter.animation_player.has_animation(profile.source_animation):
		return
	profile.duration = adapter.animation_player.get_animation(profile.source_animation).length
