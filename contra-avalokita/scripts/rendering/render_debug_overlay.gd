class_name RenderDebugOverlay
extends Control

@export var level_root: Node2D
var enabled := false
var font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F7:
			toggle()

func toggle() -> void:
	enabled = not enabled
	visible = enabled
	queue_redraw()

func _draw() -> void:
	if not enabled: return
	
	# Draw banner
	draw_rect(Rect2(8, 48, 220, 150), Color(0.02, 0.04, 0.06, 0.88))
	draw_rect(Rect2(8, 48, 220, 150), Color("4e9fa8"), false, 1.0)
	draw_string(font, Vector2(16, 64), "RENDER DOMAIN DEBUG [F7]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("62c7d4"))
	
	var lines: Array[String] = [
		"BG FAR:       Parallax 0.12  | Z -90 | M1",
		"BG DISTANT:   Parallax 0.25  | Z -70 | M2",
		"BG MID:       Parallax 0.50  | Z -50 | M2",
		"BG NEAR:      Parallax 0.80  | Z -30 | M2",
		"GAMEPLAY:     Parallax 1.00  | Z 0..19| M3/4",
		"FG NEAR:      Parallax 1.10  | Z 45  | M5",
		"FG OCCLUDER:  Parallax 1.22  | Z 65  | M5",
		"RUNTIME FX:   Behind/Body/Front/Combat",
		"SCREEN FX:    CanvasLayer 10 | Post/Flash",
		"UI LAYER:     CanvasLayer 20 | HUD/Menus"
	]
	
	for i in lines.size():
		draw_string(font, Vector2(16, 80 + i * 11), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("d4dae0"))
