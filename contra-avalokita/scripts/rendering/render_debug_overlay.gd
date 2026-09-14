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
	draw_rect(Rect2(8, 36, 260, 215), Color(0.02, 0.04, 0.06, 0.90))
	draw_rect(Rect2(8, 36, 260, 215), Color("4e9fa8"), false, 1.0)
	draw_string(font, Vector2(16, 50), "RENDER DOMAIN DEBUG [F7]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("62c7d4"))
	
	var lines: Array[String] = [
		"BG FAR:       Parallax 0.12  | Z -90 | LightMask 1",
		"BG DISTANT:   Parallax 0.25  | Z -70 | LightMask 2",
		"BG MID:       Parallax 0.50  | Z -50 | LightMask 2",
		"BG NEAR:      Parallax 0.80  | Z -25 | LightMask 2",
		"LOCAL BEHIND: Local Socket   | Z -10 | Actor Local",
		"GAMEPLAY:     Actor Internal | Z -7..7 | LightMask 4/8",
		"LOCAL BODY:   Local Socket   | Z 10  | Actor Local",
		"WORLD TRANS:  Runtime World  | Z 16  | Dust/Splatter",
		"PROJECTILE:   Runtime World  | Z 22  | Bolts/Bullets",
		"LOCAL FRONT:  Local Socket   | Z 26  | Shield/Trail",
		"DETACHED FX:  Runtime World  | Z 27  | Afterimages",
		"COMBAT FX:    Runtime World  | Z 32  | Sparks/Hits",
		"FG NEAR:      Parallax 1.10  | Z 45  | LightMask 16",
		"FG OCCLUDER:  Parallax 1.22  | Z 65  | LightMask 16",
		"EMISSIVE ART: LightMask 32   | Mask 32 (Light2D only)",
		"SCREEN FX:    CanvasLayer 10 | Post/ScreenAtmosphere",
		"UI LAYER:     CanvasLayer 20 | HUD/Menus/Debug"
	]
	
	for i in lines.size():
		draw_string(font, Vector2(16, 64 + i * 11), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("d4dae0"))
