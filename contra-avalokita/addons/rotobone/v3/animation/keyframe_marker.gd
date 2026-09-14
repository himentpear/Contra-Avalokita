@tool
class_name RotoBoneKeyframeMarker
extends Resource

enum MarkerType { CONTACT, EXTREME, BREAKDOWN, IMPACT }

const SYMBOLS := {
	MarkerType.CONTACT: "○",
	MarkerType.EXTREME: "△",
	MarkerType.BREAKDOWN: "□",
	MarkerType.IMPACT: "✕",
}

@export_range(0.0, 60.0, 0.001, "or_greater") var time := 0.0
@export var type: MarkerType = MarkerType.CONTACT
@export var bone_targets: PackedStringArray = PackedStringArray()


func symbol() -> String:
	return SYMBOLS.get(type, "○")


func type_name() -> String:
	return MarkerType.keys()[type]


func to_dictionary() -> Dictionary:
	return {
		"time": time,
		"type": type_name(),
		"bone_targets": Array(bone_targets),
	}


static func from_dictionary(data: Dictionary) -> RotoBoneKeyframeMarker:
	var marker := RotoBoneKeyframeMarker.new()
	marker.time = maxf(0.0, float(data.get("time", 0.0)))
	var requested_type := String(data.get("type", "CONTACT")).to_upper()
	marker.type = MarkerType.get(requested_type, MarkerType.CONTACT)
	marker.bone_targets = PackedStringArray(data.get("bone_targets", []))
	return marker
