@tool
extends Node2D

const Workspace := preload("res://addons/rotobone/v3/core/rotobone_workspace.gd")

var _workspace := Workspace.new()


func _ready() -> void:
	_workspace.load_catalog()
	var timeline := get_node_or_null("KeyframeMarkerLayer") as RotoBoneTimelineOverlay
	if timeline != null and _workspace.profiles.size() > 1:
		timeline.set_profile(_workspace.profiles[1])
		timeline.set_current_time(0.2)


func _exit_tree() -> void:
	_workspace.adapter.clear()
