@tool
class_name RotoPoseNode
extends Resource

enum MarkerType { CONTACT, EXTREME, BREAKDOWN, IMPACT }

@export var node_id: StringName = &"pose"
@export var display_name := "Pose"
@export var pose: RotoPose
@export var marker_type := MarkerType.BREAKDOWN
@export_multiline var meaning := ""
@export var next_nodes := PackedStringArray()


func marker_symbol() -> String:
	return ["○", "△", "□", "✕"][marker_type]
