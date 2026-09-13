class_name LevelEnvironmentController
extends Node

@export var canvas_modulate: CanvasModulate
@export var directional_light: DirectionalLight2D
@export var far_fx: Node2D
@export var mid_fx: Node2D
@export var gameplay_fx: Node2D
@export var near_fx: Node2D
@export var screen_atmosphere: ColorRect
@export var atmospheric_overlay: CanvasItem

var target_ambient_color := Color("1c242c")
var current_ambient_color := Color("1c242c")
var target_screen_tint := Color(0, 0, 0, 0)
var current_screen_tint := Color(0, 0, 0, 0)
var transition_speed := 3.0

enum Mood {
	NORMAL,
	COLD_INDUSTRIAL,
	EMERGENCY_ALARM,
	RITUAL_CHAMBER,
	DEEP_VOID,
}

var current_mood := Mood.NORMAL

func _ready() -> void:
	if not canvas_modulate:
		canvas_modulate = get_node_or_null("../World/Lighting/GlobalLighting/CanvasModulate") as CanvasModulate
	if canvas_modulate:
		current_ambient_color = canvas_modulate.color
		target_ambient_color = current_ambient_color
	if not screen_atmosphere:
		screen_atmosphere = get_node_or_null("../ScreenFX/ScreenAtmosphere") as ColorRect
	if screen_atmosphere:
		current_screen_tint = screen_atmosphere.color
		target_screen_tint = current_screen_tint

func set_mood(mood: Mood, instant: bool = false, duration: float = 1.0) -> void:
	current_mood = mood
	transition_speed = 1.0 / maxf(duration, 0.001)
	match mood:
		Mood.NORMAL:
			target_ambient_color = Color("222b35")
			target_screen_tint = Color(0.06, 0.08, 0.10, 0.05)
		Mood.COLD_INDUSTRIAL:
			target_ambient_color = Color("151e24")
			target_screen_tint = Color(0.04, 0.09, 0.14, 0.10)
		Mood.EMERGENCY_ALARM:
			target_ambient_color = Color("381418")
			target_screen_tint = Color(0.40, 0.05, 0.05, 0.15)
		Mood.RITUAL_CHAMBER:
			target_ambient_color = Color("2a1832")
			target_screen_tint = Color(0.18, 0.05, 0.22, 0.12)
		Mood.DEEP_VOID:
			target_ambient_color = Color("0a0d10")
			target_screen_tint = Color(0.02, 0.02, 0.04, 0.20)
	
	if instant:
		current_ambient_color = target_ambient_color
		current_screen_tint = target_screen_tint
		if is_instance_valid(canvas_modulate):
			canvas_modulate.color = current_ambient_color
		if is_instance_valid(screen_atmosphere):
			screen_atmosphere.color = current_screen_tint

func set_fx_intensity(scale: float) -> void:
	for fx_group in [far_fx, mid_fx, gameplay_fx, near_fx]:
		if is_instance_valid(fx_group):
			for child in fx_group.find_children("*", "GPUParticles2D"):
				var particles := child as GPUParticles2D
				particles.amount_ratio = clampf(scale, 0.0, 1.0)

func _process(delta: float) -> void:
	var factor := 1.0 - exp(-transition_speed * delta)
	if is_instance_valid(canvas_modulate) and current_ambient_color != target_ambient_color:
		current_ambient_color = current_ambient_color.lerp(target_ambient_color, factor)
		canvas_modulate.color = current_ambient_color
	if is_instance_valid(screen_atmosphere) and current_screen_tint != target_screen_tint:
		current_screen_tint = current_screen_tint.lerp(target_screen_tint, factor)
		screen_atmosphere.color = current_screen_tint
