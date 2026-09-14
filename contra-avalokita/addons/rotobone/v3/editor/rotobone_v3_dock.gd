@tool
class_name RotoBoneV3Dock
extends VBoxContainer

signal animation_selected(index: int)
signal asset_action_selected(index: int)
signal time_requested(time: float)
signal marker_requested(type: int)
signal bake_requested
signal overlay_settings_changed(opacity: float, frame: int, onion_skin: bool)

const Timeline := preload("res://addons/rotobone/v3/editor/timeline_overlay.gd")

var status_label: Label
var animation_select: OptionButton
var asset_action_select: OptionButton
var asset_mapping_label: Label
var time_spin: SpinBox
var opacity_slider: HSlider
var frame_spin: SpinBox
var onion_toggle: CheckBox
var timeline: RotoBoneTimelineOverlay


func _ready() -> void:
	custom_minimum_size = Vector2(220, 0)
	_build_ui()


func set_profiles(profiles: Array[RotoBoneAnimationProfile]) -> void:
	animation_select.clear()
	for profile in profiles:
		var title := String(profile.animation_name).capitalize()
		if profile.animation_name == &"slash":
			title = "Attack / Slash"
		animation_select.add_item(title)
		animation_select.set_item_metadata(animation_select.item_count - 1, String(profile.animation_name))
	if not profiles.is_empty():
		animation_select.select(0)


func set_asset_actions(actions: Array[Dictionary]) -> void:
	asset_action_select.clear()
	for action in actions:
		asset_action_select.add_item(String(action.get("folder", "Unnamed")))
	if not actions.is_empty():
		asset_action_select.select(0)
		set_asset_action(actions[0])


func select_asset_action(index: int) -> void:
	if index >= 0 and index < asset_action_select.item_count:
		asset_action_select.select(index)


func set_asset_action(action: Dictionary) -> void:
	var canonical := String(action.get("canonical_action", ""))
	var source := String(action.get("source_animation", ""))
	var mapping := String(action.get("mapping", "excluded"))
	if mapping == "excluded":
		asset_mapping_label.text = "Excluded from v3 authoring"
	elif source.is_empty():
		asset_mapping_label.text = "%s → %s (new clip)" % [mapping.capitalize(), canonical]
	else:
		asset_mapping_label.text = "%s → %s → %s" % [mapping.capitalize(), canonical, source]


func set_template_status(_ready: bool, message: String) -> void:
	status_label.text = message
	status_label.modulate = Color("72d6a0") if _ready else Color("ffb86c")


func set_profile(profile: RotoBoneAnimationProfile) -> void:
	timeline.set_profile(profile)
	time_spin.max_value = profile.duration
	for index in animation_select.item_count:
		if StringName(animation_select.get_item_metadata(index)) == profile.animation_name:
			animation_select.select(index)
			break


func set_time(value: float) -> void:
	time_spin.set_value_no_signal(value)
	timeline.set_current_time(value)


func _build_ui() -> void:
	var title := Label.new()
	title.text = "RotoBone v3"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Mud Character"
	subtitle.add_theme_color_override("font_color", Color("a7c7ff"))
	add_child(subtitle)
	status_label = Label.new()
	status_label.text = "Detecting template…"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	var pose_hint := Label.new()
	pose_hint.text = "Rotation-only pose mode · use Rotate (E)"
	pose_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pose_hint.add_theme_color_override("font_color", Color("ffca6b"))
	add_child(pose_hint)
	add_child(HSeparator.new())

	animation_select = OptionButton.new()
	animation_select.tooltip_text = "Canonical mud_character action profile"
	animation_select.item_selected.connect(func(index: int) -> void: animation_selected.emit(index))
	add_child(animation_select)
	var asset_label := Label.new()
	asset_label.text = "Asset action directory"
	add_child(asset_label)
	asset_action_select = OptionButton.new()
	asset_action_select.tooltip_text = "Reference folders under the 2D Pixel Art Character Template"
	asset_action_select.item_selected.connect(func(index: int) -> void: asset_action_selected.emit(index))
	add_child(asset_action_select)
	asset_mapping_label = Label.new()
	asset_mapping_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asset_mapping_label.add_theme_color_override("font_color", Color("aab2c4"))
	add_child(asset_mapping_label)
	time_spin = SpinBox.new()
	time_spin.step = 0.001
	time_spin.suffix = " s"
	time_spin.value_changed.connect(func(value: float) -> void: time_requested.emit(value))
	add_child(time_spin)
	timeline = Timeline.new()
	timeline.time_requested.connect(func(value: float) -> void: time_requested.emit(value))
	add_child(timeline)

	var marker_label := Label.new()
	marker_label.text = "Keyframe markers"
	add_child(marker_label)
	var marker_grid := GridContainer.new()
	marker_grid.columns = 2
	var labels := ["○ Contact", "△ Extreme", "□ Breakdown", "✕ Impact"]
	for index in labels.size():
		var button := Button.new()
		button.text = labels[index]
		button.pressed.connect(func() -> void: marker_requested.emit(index))
		marker_grid.add_child(button)
	add_child(marker_grid)

	var ref_label := Label.new()
	ref_label.text = "Reference overlay"
	add_child(ref_label)
	opacity_slider = HSlider.new()
	opacity_slider.min_value = 0.0
	opacity_slider.max_value = 1.0
	opacity_slider.step = 0.01
	opacity_slider.value = 0.42
	opacity_slider.value_changed.connect(_emit_overlay_settings)
	add_child(opacity_slider)
	frame_spin = SpinBox.new()
	frame_spin.min_value = 0
	frame_spin.max_value = 127
	frame_spin.step = 1
	frame_spin.prefix = "Frame "
	frame_spin.value_changed.connect(_emit_overlay_settings)
	add_child(frame_spin)
	onion_toggle = CheckBox.new()
	onion_toggle.text = "Onion skin"
	onion_toggle.button_pressed = true
	onion_toggle.toggled.connect(func(_value: bool) -> void: _emit_overlay_settings(0.0))
	add_child(onion_toggle)

	var bake_button := Button.new()
	bake_button.text = "Bake Pose"
	bake_button.pressed.connect(func() -> void: bake_requested.emit())
	add_child(bake_button)
	var add_button := Button.new()
	add_button.text = "Add Marker"
	add_button.tooltip_text = "Adds a Breakdown marker at the current time"
	add_button.pressed.connect(func() -> void: marker_requested.emit(2))
	add_child(add_button)


func _emit_overlay_settings(_value: float) -> void:
	overlay_settings_changed.emit(opacity_slider.value, int(frame_spin.value), onion_toggle.button_pressed)
