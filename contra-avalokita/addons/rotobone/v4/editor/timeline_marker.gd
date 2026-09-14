@tool
class_name RotoTimelineMarker
extends Resource

enum Type { CONTACT, EXTREME, BREAKDOWN, IMPACT }

@export var time := 0.0
@export var type := Type.BREAKDOWN
@export var label := "pose"


func symbol() -> String:
	return ["○", "△", "□", "✕"][type]
