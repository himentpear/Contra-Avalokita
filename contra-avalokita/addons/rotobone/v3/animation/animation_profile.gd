@tool
class_name RotoBoneAnimationProfile
extends Resource

@export var animation_name: StringName
@export var source_animation: StringName
@export_range(0.01, 60.0, 0.001, "or_greater") var duration := 1.0
@export_file("*.png", "*.webp", "*.svg") var reference_sprite := ""
@export var markers: Array[RotoBoneKeyframeMarker] = []


func add_marker(marker: RotoBoneKeyframeMarker) -> void:
	markers.append(marker)
	markers.sort_custom(func(a: RotoBoneKeyframeMarker, b: RotoBoneKeyframeMarker) -> bool: return a.time < b.time)
	emit_changed()


func to_dictionary() -> Dictionary:
	var marker_data: Array[Dictionary] = []
	for marker in markers:
		marker_data.append(marker.to_dictionary())
	return {
		"animation_name": String(animation_name),
		"source_animation": String(source_animation),
		"duration": duration,
		"reference_sprite": reference_sprite,
		"markers": marker_data,
	}


static func from_dictionary(data: Dictionary) -> RotoBoneAnimationProfile:
	var profile := RotoBoneAnimationProfile.new()
	profile.animation_name = StringName(data.get("animation_name", ""))
	profile.source_animation = StringName(data.get("source_animation", profile.animation_name))
	profile.duration = maxf(0.01, float(data.get("duration", 1.0)))
	profile.reference_sprite = String(data.get("reference_sprite", ""))
	for marker_data in data.get("markers", []):
		if marker_data is Dictionary:
			profile.markers.append(RotoBoneKeyframeMarker.from_dictionary(marker_data))
	return profile
