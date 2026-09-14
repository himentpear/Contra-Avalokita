extends Node2D

const VIRTUAL_SIZE := Vector2(640.0, 360.0)
const IMPACT_COUNT := 4

@onready var sea_body: ColorRect = $SeaBody
@onready var hud_panel: ColorRect = $HUD/Panel
@onready var debug_label: Label = $HUD/DebugLabel

var ocean_time := 0.0
var amplitude_px := 8.0
var wave_speed := 0.65
var roughness := 0.75
var highlight_intensity := 0.90
var foam_px := 2.0
var _material: ShaderMaterial
var _hud_visible := true

var impacts: Array[Vector4] = [
	Vector4(-10.0, 99.0, 0.0, 0.08),
	Vector4(-10.0, 99.0, 0.0, 0.08),
	Vector4(-10.0, 99.0, 0.0, 0.08),
	Vector4(-10.0, 99.0, 0.0, 0.08),
]


func _ready() -> void:
	_material = sea_body.material as ShaderMaterial
	if _material == null:
		push_error("OceanWaveTest requires a ShaderMaterial on SeaBody")
		set_process(false)
		return
	_apply_parameters()
	_push_impacts()
	_update_debug_label()


func _process(delta: float) -> void:
	ocean_time += delta
	_material.set_shader_parameter("u_time", ocean_time)

	for index in range(IMPACT_COUNT):
		var impact := impacts[index]
		impact.y += delta
		impacts[index] = impact
		_material.set_shader_parameter("impact%d" % index, impact)

	_handle_continuous_tuning(delta)
	_update_debug_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_1:
				set_preset(&"calm")
			KEY_2:
				set_preset(&"medium")
			KEY_3:
				set_preset(&"storm")
			KEY_SPACE:
				add_impact(VIRTUAL_SIZE.x * 0.5, 8.0, 64.0)
			KEY_H:
				_hud_visible = not _hud_visible
				hud_panel.visible = _hud_visible
				debug_label.visible = _hud_visible

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			add_impact(mouse_event.position.x, 6.0, 48.0)


func _handle_continuous_tuning(delta: float) -> void:
	var changed := false

	if Input.is_key_pressed(KEY_Q):
		amplitude_px = maxf(0.0, amplitude_px - 8.0 * delta)
		changed = true
	if Input.is_key_pressed(KEY_E):
		amplitude_px = minf(24.0, amplitude_px + 8.0 * delta)
		changed = true
	if Input.is_key_pressed(KEY_A):
		wave_speed = maxf(0.0, wave_speed - 0.8 * delta)
		changed = true
	if Input.is_key_pressed(KEY_D):
		wave_speed = minf(3.0, wave_speed + 0.8 * delta)
		changed = true
	if Input.is_key_pressed(KEY_Z):
		roughness = maxf(0.0, roughness - 0.7 * delta)
		changed = true
	if Input.is_key_pressed(KEY_C):
		roughness = minf(2.0, roughness + 0.7 * delta)
		changed = true

	if changed:
		_apply_parameters()


func set_preset(preset: StringName) -> void:
	match preset:
		&"calm":
			amplitude_px = 3.5
			wave_speed = 0.32
			roughness = 0.28
			highlight_intensity = 0.58
			foam_px = 1.0
		&"storm":
			amplitude_px = 13.0
			wave_speed = 1.02
			roughness = 1.35
			highlight_intensity = 1.12
			foam_px = 3.0
		_:
			amplitude_px = 8.0
			wave_speed = 0.65
			roughness = 0.75
			highlight_intensity = 0.90
			foam_px = 2.0
	_apply_parameters()


func add_impact(viewport_x_px: float, strength_px: float = 6.0, radius_px: float = 48.0) -> void:
	if _material == null:
		return

	var oldest_index := 0
	var oldest_age := -1.0
	for index in range(IMPACT_COUNT):
		if impacts[index].y > oldest_age:
			oldest_age = impacts[index].y
			oldest_index = index

	impacts[oldest_index] = Vector4(
		clampf(viewport_x_px / VIRTUAL_SIZE.x, 0.0, 1.0),
		0.0,
		maxf(strength_px, 0.0),
		maxf(radius_px / VIRTUAL_SIZE.x, 0.001)
	)
	_material.set_shader_parameter("impact%d" % oldest_index, impacts[oldest_index])


func get_ocean_material() -> ShaderMaterial:
	return _material


func _apply_parameters() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("virtual_size", VIRTUAL_SIZE)
	_material.set_shader_parameter("amplitude_px", amplitude_px)
	_material.set_shader_parameter("wave_speed", wave_speed)
	_material.set_shader_parameter("roughness", roughness)
	_material.set_shader_parameter("highlight_intensity", highlight_intensity)
	_material.set_shader_parameter("foam_px", foam_px)


func _push_impacts() -> void:
	if _material == null:
		return
	for index in range(IMPACT_COUNT):
		_material.set_shader_parameter("impact%d" % index, impacts[index])


func _update_debug_label() -> void:
	if debug_label == null:
		return
	debug_label.text = (
		"BLACK OCEAN / FRONT VIEW\n"
		+ "1 Calm   2 Medium   3 Storm   H HUD\n"
		+ "Q/E amplitude  %.2f px\n" % amplitude_px
		+ "A/D speed      %.2f\n" % wave_speed
		+ "Z/C roughness  %.2f\n" % roughness
		+ "LMB / Space    inject disturbance"
	)
