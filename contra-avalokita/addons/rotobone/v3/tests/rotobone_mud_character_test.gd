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
	var action_list := get_node_or_null("ActionCatalogPanel/Margin/VBox/ActionList") as ItemList
	if action_list != null:
		action_list.clear()
		for action in _workspace.asset_actions:
			var canonical := String(action.get("canonical_action", "—"))
			var mapping := String(action.get("mapping", "excluded"))
			var suffix := "excluded" if mapping == "excluded" else "%s · %s" % [canonical, mapping]
			action_list.add_item("%s  →  %s" % [action.get("folder", ""), suffix])
			action_list.set_item_tooltip(action_list.item_count - 1, String(action.get("reference_sprite", "")))


func _exit_tree() -> void:
	_workspace.adapter.clear()
