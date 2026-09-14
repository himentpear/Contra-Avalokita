@tool
class_name RotoBonePanel
extends VBoxContainer

signal state_changed
signal request_refresh_players
signal player_index_changed(index: int)
signal request_create_anchor
signal request_select_anchor
signal request_create_standard_rig

const CATALOG_PATH := "res://addons/rotobone/presets/sample_animation_catalog.json"

var reference_texture: Texture2D
var reference_path: String = ""
var frame_size := Vector2i(48, 48)
var frame_count: int = 1
var frame_durations_ms: PackedInt32Array = PackedInt32Array([100])
var frame_index: int = 0
var opacity: float = 0.58
var reference_scale: float = 1.0
var anchor_px := Vector2(24.0, 40.0)
var loop: bool = true
var flip_h: bool = false
var onion_skin: bool = true
var show_bounds: bool = true
var sync_enabled: bool = true
var clip_id: String = ""
var timing_note: String = ""

var _catalog_by_basename: Dictionary = {}
var _updating_ui := false

var _path_label: Label
var _meta_label: Label
var _anchor_label: Label
var _frame_spin: SpinBox
var _frame_w_spin: SpinBox
var _frame_h_spin: SpinBox
var _duration_spin: SpinBox
var _opacity_slider: HSlider
var _scale_spin: SpinBox
var _anchor_x_spin: SpinBox
var _anchor_y_spin: SpinBox
var _loop_check: CheckBox
var _flip_check: CheckBox
var _onion_check: CheckBox
var _bounds_check: CheckBox
var _sync_check: CheckBox
var _player_option: OptionButton
var _animation_label: Label
var _file_dialog: FileDialog


func _ready() -> void:
	_load_catalog()
	_build_ui()
	_sync_ui_from_state()


func _build_ui() -> void:
	# Narrow by design: all world-space X/Y positioning is moved into one
	# draggable Marker2D instead of consuming dock width with offset controls.
	custom_minimum_size = Vector2(196, 0)
	add_theme_constant_override("separation", 5)

	var header := HBoxContainer.new()
	add_child(header)
	var title := Label.new()
	title.text = "RotoBone 0.2"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var refresh_button := Button.new()
	refresh_button.text = "↻"
	refresh_button.tooltip_text = "Refresh AnimationPlayer list"
	refresh_button.custom_minimum_size.x = 28
	refresh_button.pressed.connect(func(): request_refresh_players.emit())
	header.add_child(refresh_button)

	var tools := HBoxContainer.new()
	add_child(tools)
	var load_button := Button.new()
	load_button.text = "PNG"
	load_button.tooltip_text = "Load reference sprite sheet"
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.pressed.connect(_open_reference_dialog)
	tools.add_child(load_button)
	var anchor_button := Button.new()
	anchor_button.text = "+ Pos"
	anchor_button.tooltip_text = "Create/select RotoBoneAnchor. Drag this Marker2D to position the reference on X/Y."
	anchor_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	anchor_button.pressed.connect(func(): request_create_anchor.emit())
	tools.add_child(anchor_button)
	var rig_button := Button.new()
	rig_button.text = "+ Rig"
	rig_button.tooltip_text = "Insert a standard 48px side-view Skeleton2D sample at the position anchor."
	rig_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rig_button.pressed.connect(func(): request_create_standard_rig.emit())
	tools.add_child(rig_button)

	_path_label = Label.new()
	_path_label.text = "No PNG"
	_path_label.clip_text = true
	_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_path_label)

	_meta_label = Label.new()
	_meta_label.text = "48×48 · 1f"
	_meta_label.clip_text = true
	_meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_meta_label)

	add_child(HSeparator.new())
	add_child(_section_label("FRAME"))

	var size_grid := GridContainer.new()
	size_grid.columns = 2
	add_child(size_grid)
	_frame_w_spin = _add_compact_spin(size_grid, "W", 1, 1024, 1, 48)
	_frame_h_spin = _add_compact_spin(size_grid, "H", 1, 1024, 1, 48)
	_frame_w_spin.value_changed.connect(_on_frame_size_changed)
	_frame_h_spin.value_changed.connect(_on_frame_size_changed)

	var frame_row := HBoxContainer.new()
	add_child(frame_row)
	var prev_button := Button.new()
	prev_button.text = "◀"
	prev_button.custom_minimum_size.x = 30
	prev_button.pressed.connect(func(): set_frame_index(frame_index - 1))
	frame_row.add_child(prev_button)
	_frame_spin = SpinBox.new()
	_frame_spin.min_value = 0
	_frame_spin.max_value = 0
	_frame_spin.step = 1
	_frame_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame_spin.value_changed.connect(func(v): set_frame_index(int(v)))
	frame_row.add_child(_frame_spin)
	var next_button := Button.new()
	next_button.text = "▶"
	next_button.custom_minimum_size.x = 30
	next_button.pressed.connect(func(): set_frame_index(frame_index + 1))
	frame_row.add_child(next_button)

	var timing_row := HBoxContainer.new()
	add_child(timing_row)
	var ms_label := Label.new()
	ms_label.text = "ms"
	timing_row.add_child(ms_label)
	_duration_spin = SpinBox.new()
	_duration_spin.min_value = 1
	_duration_spin.max_value = 5000
	_duration_spin.step = 1
	_duration_spin.value = 100
	_duration_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_duration_spin.value_changed.connect(_on_uniform_duration_changed)
	timing_row.add_child(_duration_spin)
	_loop_check = CheckBox.new()
	_loop_check.text = "Loop"
	_loop_check.button_pressed = true
	_loop_check.toggled.connect(func(v):
		loop = v
		state_changed.emit()
	)
	timing_row.add_child(_loop_check)

	add_child(HSeparator.new())
	add_child(_section_label("TRACE"))

	var opacity_row := HBoxContainer.new()
	add_child(opacity_row)
	var opacity_label := Label.new()
	opacity_label.text = "Alpha"
	opacity_row.add_child(opacity_label)
	_opacity_slider = HSlider.new()
	_opacity_slider.min_value = 0.05
	_opacity_slider.max_value = 1.0
	_opacity_slider.step = 0.01
	_opacity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opacity_slider.value_changed.connect(func(v):
		opacity = float(v)
		state_changed.emit()
	)
	opacity_row.add_child(_opacity_slider)

	var trace_grid := GridContainer.new()
	trace_grid.columns = 2
	add_child(trace_grid)
	_scale_spin = _add_compact_spin(trace_grid, "Scale", 0.1, 16.0, 0.05, 1.0)
	_anchor_x_spin = _add_compact_spin(trace_grid, "Pivot X", -2048, 2048, 0.25, 24)
	_anchor_y_spin = _add_compact_spin(trace_grid, "Pivot Y", -2048, 2048, 0.25, 40)
	_scale_spin.value_changed.connect(func(v):
		reference_scale = float(v)
		state_changed.emit()
	)
	_anchor_x_spin.value_changed.connect(_on_anchor_changed)
	_anchor_y_spin.value_changed.connect(_on_anchor_changed)

	var flags_row := HFlowContainer.new()
	flags_row.alignment = FlowContainer.ALIGNMENT_BEGIN
	add_child(flags_row)
	_onion_check = CheckBox.new()
	_onion_check.text = "Onion"
	_onion_check.button_pressed = true
	_onion_check.toggled.connect(func(v):
		onion_skin = v
		state_changed.emit()
	)
	flags_row.add_child(_onion_check)
	_flip_check = CheckBox.new()
	_flip_check.text = "Flip"
	_flip_check.toggled.connect(func(v):
		flip_h = v
		state_changed.emit()
	)
	flags_row.add_child(_flip_check)
	_bounds_check = CheckBox.new()
	_bounds_check.text = "Box"
	_bounds_check.button_pressed = true
	_bounds_check.toggled.connect(func(v):
		show_bounds = v
		state_changed.emit()
	)
	flags_row.add_child(_bounds_check)

	add_child(HSeparator.new())
	add_child(_section_label("BIND"))

	var anchor_row := HBoxContainer.new()
	add_child(anchor_row)
	_anchor_label = Label.new()
	_anchor_label.text = "Pos: <create>"
	_anchor_label.clip_text = true
	_anchor_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_anchor_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	anchor_row.add_child(_anchor_label)
	var select_anchor_button := Button.new()
	select_anchor_button.text = "◎"
	select_anchor_button.tooltip_text = "Select the RotoBoneAnchor Marker2D"
	select_anchor_button.custom_minimum_size.x = 28
	select_anchor_button.pressed.connect(func(): request_select_anchor.emit())
	anchor_row.add_child(select_anchor_button)

	_player_option = OptionButton.new()
	_player_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_option.tooltip_text = "AnimationPlayer used for reference-frame time sync"
	_player_option.item_selected.connect(func(i): player_index_changed.emit(i))
	add_child(_player_option)

	_sync_check = CheckBox.new()
	_sync_check.text = "Sync time"
	_sync_check.button_pressed = true
	_sync_check.tooltip_text = "Follow the selected AnimationPlayer timeline"
	_sync_check.toggled.connect(func(v):
		sync_enabled = v
		state_changed.emit()
	)
	add_child(_sync_check)

	_animation_label = Label.new()
	_animation_label.text = "Anim: —"
	_animation_label.clip_text = true
	_animation_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_animation_label)

	var safety := Label.new()
	safety.text = "Pos node = world X/Y · bones stay rest-safe"
	safety.tooltip_text = "RotoBone moves the reference with a Marker2D. The overlay does not write Bone2D.rest, bone length, bone scale, or animation keys."
	safety.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safety.add_theme_font_size_override("font_size", 11)
	add_child(safety)

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.png ; PNG sprite sheets"])
	_file_dialog.file_selected.connect(_on_reference_selected)
	add_child(_file_dialog)


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	return label


func _add_compact_spin(
	parent: GridContainer,
	text: String,
	min_value: float,
	max_value: float,
	step: float,
	default_value: float
) -> SpinBox:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 46
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = default_value
	spin.custom_minimum_size.x = 58
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	parent.add_child(row)
	return spin


func _open_reference_dialog() -> void:
	_file_dialog.popup_centered_ratio(0.72)


func _on_reference_selected(path: String) -> void:
	var loaded := load(path)
	if not (loaded is Texture2D):
		_meta_label.text = "Load failed"
		_meta_label.tooltip_text = "Could not load texture: %s" % path
		return
	reference_texture = loaded as Texture2D
	reference_path = path
	_apply_metadata_for_texture()
	_sync_ui_from_state()
	state_changed.emit()


func _load_catalog() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not (parsed is Dictionary):
		return
	var clips: Array = parsed.get("clips", [])
	for clip in clips:
		if clip is Dictionary:
			var source_path := String(clip.get("source_png", ""))
			var basename := source_path.get_file().to_lower()
			if not basename.is_empty():
				_catalog_by_basename[basename] = clip


func _apply_metadata_for_texture() -> void:
	clip_id = ""
	timing_note = ""
	var basename := reference_path.get_file().to_lower()
	if _catalog_by_basename.has(basename):
		var entry: Dictionary = _catalog_by_basename[basename]
		clip_id = String(entry.get("id", ""))
		var fs: Array = entry.get("frame_size", [48, 48])
		frame_size = Vector2i(int(fs[0]), int(fs[1]))
		frame_count = maxi(int(entry.get("frame_count", 1)), 1)
		frame_durations_ms = PackedInt32Array()
		for duration in entry.get("frame_durations_ms", []):
			frame_durations_ms.append(maxi(int(duration), 1))
		if frame_durations_ms.size() != frame_count:
			_fill_uniform_timing(100)
		loop = bool(entry.get("loop", true))
		var anchor_data: Array = entry.get("anchor_px", [frame_size.x * 0.5, frame_size.y * 0.84])
		anchor_px = Vector2(float(anchor_data[0]), float(anchor_data[1]))
		timing_note = String(entry.get("timing_source", "catalog"))
	else:
		_auto_detect_sheet()
	frame_index = clampi(frame_index, 0, frame_count - 1)


func _auto_detect_sheet() -> void:
	if reference_texture == null:
		return
	var width := reference_texture.get_width()
	var height := reference_texture.get_height()
	if height > 0 and width % height == 0:
		frame_size = Vector2i(height, height)
		frame_count = maxi(int(width / height), 1)
	else:
		frame_size = Vector2i(width, height)
		frame_count = 1
	anchor_px = Vector2(frame_size.x * 0.5, frame_size.y * 0.84)
	_fill_uniform_timing(100)
	timing_note = "auto"


func _fill_uniform_timing(duration_ms: int) -> void:
	frame_durations_ms = PackedInt32Array()
	for _i in range(frame_count):
		frame_durations_ms.append(maxi(duration_ms, 1))


func _on_frame_size_changed(_value: float) -> void:
	if _updating_ui:
		return
	frame_size = Vector2i(int(_frame_w_spin.value), int(_frame_h_spin.value))
	_recalculate_frame_count()
	anchor_px = Vector2(frame_size.x * 0.5, frame_size.y * 0.84)
	_fill_uniform_timing(int(_duration_spin.value))
	_sync_ui_from_state()
	state_changed.emit()


func _recalculate_frame_count() -> void:
	if reference_texture == null or frame_size.x <= 0 or frame_size.y <= 0:
		frame_count = 1
		return
	var columns := int(reference_texture.get_width() / frame_size.x)
	var rows := int(reference_texture.get_height() / frame_size.y)
	frame_count = maxi(columns * rows, 1)
	frame_index = clampi(frame_index, 0, frame_count - 1)


func _on_uniform_duration_changed(value: float) -> void:
	if _updating_ui:
		return
	_fill_uniform_timing(int(value))
	timing_note = "manual"
	_update_meta_label()
	state_changed.emit()


func _on_anchor_changed(_value: float) -> void:
	if _updating_ui:
		return
	anchor_px = Vector2(float(_anchor_x_spin.value), float(_anchor_y_spin.value))
	state_changed.emit()


func _sync_ui_from_state() -> void:
	if not is_node_ready():
		return
	_updating_ui = true
	_path_label.text = reference_path.get_file() if not reference_path.is_empty() else "No PNG"
	_path_label.tooltip_text = reference_path
	_frame_w_spin.value = frame_size.x
	_frame_h_spin.value = frame_size.y
	_frame_spin.max_value = maxi(frame_count - 1, 0)
	_frame_spin.value = frame_index
	_duration_spin.value = _representative_duration_ms()
	_opacity_slider.value = opacity
	_scale_spin.value = reference_scale
	_anchor_x_spin.value = anchor_px.x
	_anchor_y_spin.value = anchor_px.y
	_loop_check.button_pressed = loop
	_flip_check.button_pressed = flip_h
	_onion_check.button_pressed = onion_skin
	_bounds_check.button_pressed = show_bounds
	_sync_check.button_pressed = sync_enabled
	_update_meta_label()
	_updating_ui = false


func _representative_duration_ms() -> int:
	if frame_durations_ms.is_empty():
		return 100
	return frame_durations_ms[0]


func _update_meta_label() -> void:
	if reference_texture == null:
		_meta_label.text = "48×48 · 1f"
		_meta_label.tooltip_text = "Load a sprite sheet. Sample-pack filenames are recognized automatically."
		return
	var duration_ms := 0
	for value in frame_durations_ms:
		duration_ms += value
	var id_text := clip_id if not clip_id.is_empty() else "custom"
	_meta_label.text = "%dx%d · %df · %.2fs" % [
		frame_size.x,
		frame_size.y,
		frame_count,
		float(duration_ms) / 1000.0
	]
	_meta_label.tooltip_text = "%s · %s" % [id_text, timing_note]


func set_frame_index(index: int) -> void:
	if frame_count <= 0:
		frame_count = 1
	var next_index := index
	if loop:
		next_index = posmod(index, frame_count)
	else:
		next_index = clampi(index, 0, frame_count - 1)
	if next_index == frame_index and not _updating_ui:
		return
	frame_index = next_index
	if is_node_ready():
		_updating_ui = true
		_frame_spin.value = frame_index
		_updating_ui = false
	state_changed.emit()


func set_frame_index_from_sync(index: int) -> void:
	if index == frame_index:
		return
	frame_index = clampi(index, 0, maxi(frame_count - 1, 0))
	if is_node_ready():
		_updating_ui = true
		_frame_spin.value = frame_index
		_updating_ui = false


func frame_at_time(time_seconds: float) -> int:
	if frame_count <= 1:
		return 0
	var total_seconds := 0.0
	for i in range(frame_count):
		total_seconds += float(_duration_for_frame(i)) / 1000.0
	if total_seconds <= 0.0:
		return 0
	var t := time_seconds
	if loop:
		t = fposmod(t, total_seconds)
	else:
		t = clampf(t, 0.0, maxf(total_seconds - 0.000001, 0.0))
	var cursor := 0.0
	for i in range(frame_count):
		cursor += float(_duration_for_frame(i)) / 1000.0
		if t < cursor:
			return i
	return frame_count - 1


func _duration_for_frame(index: int) -> int:
	if frame_durations_ms.is_empty():
		return 100
	return maxi(frame_durations_ms[clampi(index, 0, frame_durations_ms.size() - 1)], 1)


func source_rect(index: int) -> Rect2:
	if reference_texture == null:
		return Rect2()
	var columns := maxi(int(reference_texture.get_width() / frame_size.x), 1)
	var safe := clampi(index, 0, maxi(frame_count - 1, 0))
	var column := safe % columns
	var row := int(safe / columns)
	return Rect2(Vector2(column * frame_size.x, row * frame_size.y), Vector2(frame_size))


func set_anchor_node_name(text: String) -> void:
	if is_node_ready():
		_anchor_label.text = "Pos: %s" % text.get_file()
		_anchor_label.tooltip_text = text


func set_animation_players(names: PackedStringArray, selected_index: int = 0) -> void:
	if not is_node_ready():
		return
	_updating_ui = true
	_player_option.clear()
	for player_name in names:
		_player_option.add_item(player_name.get_file())
		_player_option.set_item_tooltip(_player_option.item_count - 1, player_name)
	if _player_option.item_count > 0:
		_player_option.select(clampi(selected_index, 0, _player_option.item_count - 1))
	else:
		_player_option.add_item("No AnimationPlayer")
		_player_option.disabled = true
	if names.size() > 0:
		_player_option.disabled = false
	_updating_ui = false


func set_current_animation_text(text: String) -> void:
	if is_node_ready():
		_animation_label.text = "Anim: %s" % (text if not text.is_empty() else "—")
		_animation_label.tooltip_text = text
