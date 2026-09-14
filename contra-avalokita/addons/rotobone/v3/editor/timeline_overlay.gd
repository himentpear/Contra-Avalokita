@tool
class_name RotoBoneTimelineOverlay
extends Control

signal time_requested(time: float)

const Marker := preload("res://addons/rotobone/v3/animation/keyframe_marker.gd")
const COLORS := {
	Marker.MarkerType.CONTACT: Color("72d6a0"),
	Marker.MarkerType.EXTREME: Color("ffd166"),
	Marker.MarkerType.BREAKDOWN: Color("7db4ff"),
	Marker.MarkerType.IMPACT: Color("ff6b6b"),
}

@export var profile: RotoBoneAnimationProfile:
	set(value):
		profile = value
		queue_redraw()
var current_time := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(200, 54)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_profile(value: RotoBoneAnimationProfile) -> void:
	profile = value
	queue_redraw()


func set_current_time(value: float) -> void:
	current_time = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var duration := profile.duration if profile != null else 1.0
		var requested := clampf((event.position.x - 8.0) / maxf(1.0, size.x - 16.0), 0.0, 1.0) * duration
		time_requested.emit(requested)
		accept_event()


func _draw() -> void:
	var left := 8.0
	var right := maxf(left + 1.0, size.x - 8.0)
	var baseline := 35.0
	draw_line(Vector2(left, baseline), Vector2(right, baseline), Color(0.55, 0.58, 0.64), 1.0)
	var duration := profile.duration if profile != null else 1.0
	if profile != null:
		for marker in profile.markers:
			var x := lerpf(left, right, clampf(marker.time / duration, 0.0, 1.0))
			draw_string(get_theme_default_font(), Vector2(x - 5.0, 25.0), marker.symbol(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, COLORS.get(marker.type, Color.WHITE))
	var cursor_x := lerpf(left, right, clampf(current_time / duration, 0.0, 1.0))
	draw_line(Vector2(cursor_x, 8.0), Vector2(cursor_x, 45.0), Color("f4f7ff"), 2.0)
	draw_string(get_theme_default_font(), Vector2(left, 52.0), "%.3fs" % current_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.76, 0.79, 0.84))
