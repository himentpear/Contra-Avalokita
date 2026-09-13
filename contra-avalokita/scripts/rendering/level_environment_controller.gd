class_name LevelEnvironmentController
extends Node

@export var canvas_modulate: CanvasModulate
@export var directional_light: DirectionalLight2D
@export var far_fx: Node2D
@export var mid_fx: Node2D
@export var near_fx: Node2D
@export var atmospheric_overlay: CanvasItem

var target_ambient_color := Color("1c242c")
var current_ambient_color := Color("1c242c")
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

func set_mood(mood: Mood, duration: float = 1.0) -> void:
	current_mood = mood
	transition_speed = 1.0 / maxf(duration, 0.001)
	match mood:
		Mood.NORMAL:
			target_ambient_color = Color("222b35")
		Mood.COLD_INDUSTRIAL:
			target_ambient_color = Color("151e24")
		Mood.EMERGENCY_ALARM:
			target_ambient_color = Color("381418")
		Mood.RITUAL_CHAMBER:
			target_ambient_color = Color("2a1832")
		Mood.DEEP_VOID:
			target_ambient_color = Color("0a0d10")

func set_fx_intensity(scale: float) -> void:
	for fx_group in [far_fx, mid_fx, near_fx]:
		if is_instance_valid(fx_group):
			for child in fx_group.find_children("*", "GPUParticles2D"):
				var particles := child as GPUParticles2D
				particles.amount_ratio = clampf(scale, 0.0, 1.0)

func _process(delta: float) -> void:
	if is_instance_valid(canvas_modulate) and current_ambient_color != target_ambient_color:
		current_ambient_color = current_ambient_color.lerp(target_ambient_color, 1.0 - exp(-transition_speed * delta))
		canvas_modulate.color = current_ambient_color
