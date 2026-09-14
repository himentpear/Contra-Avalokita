@tool
class_name RotoPoseEditorDock
extends VBoxContainer

signal pose_selected(index: int)
signal capture_requested
signal export_requested
signal bake_requested
signal target_visibility_changed(target_name: StringName, enabled: bool)

var _character_label: Label
var _animation_label: Label
var _pose_list: ItemList
var _status: Label


func _ready() -> void:
	custom_minimum_size = Vector2(290, 0)
	var title := Label.new()
	title.text = "RotoPose"
	title.add_theme_font_size_override("font_size", 20)
	add_child(title)
	_character_label = _label("Character: [not detected]")
	_animation_label = _label("Animation: [none]")
	add_child(_character_label)
	add_child(_animation_label)
	add_child(HSeparator.new())
	add_child(_label("Pose Graph"))
	_pose_list = ItemList.new()
	_pose_list.custom_minimum_size.y = 150
	_pose_list.item_selected.connect(func(index: int) -> void: pose_selected.emit(index))
	add_child(_pose_list)
	add_child(_label("Targets"))
	var target_grid := GridContainer.new()
	target_grid.columns = 2
	for target_name in ["hand_r", "hand_l", "foot_r", "foot_l", "weapon_tip", "body"]:
		var toggle := CheckBox.new()
		toggle.text = target_name.replace("_", " ").capitalize()
		toggle.button_pressed = true
		toggle.toggled.connect(_on_target_toggled.bind(StringName(target_name)))
		target_grid.add_child(toggle)
	add_child(target_grid)
	add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.add_child(_button("Capture Pose", capture_requested.emit))
	buttons.add_child(_button("Export AI Data", export_requested.emit))
	buttons.add_child(_button("Bake Runtime", bake_requested.emit))
	add_child(buttons)
	_status = _label("Edit targets, not Bone2D nodes.")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)


func set_character_status(detected: bool) -> void:
	_character_label.text = "Character: [Mud Character]" if detected else "Character: [not detected]"


func set_graph(graph: RotoPoseGraph) -> void:
	_pose_list.clear()
	_animation_label.text = "Animation: [%s]" % (String(graph.graph_name) if graph != null else "none")
	if graph == null:
		return
	for node in graph.sorted_nodes():
		_pose_list.add_item("%s  %s" % [node.marker_symbol(), node.display_name])


func set_status(message: String) -> void:
	_status.text = message


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _on_target_toggled(enabled: bool, target_name: StringName) -> void:
	target_visibility_changed.emit(target_name, enabled)
