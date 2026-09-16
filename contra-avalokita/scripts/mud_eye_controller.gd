class_name MudEyeController
extends Node2D
@export var blink_interval := 4.2
@export var blink_duration := 0.13
@export var eye_color := Color("eff6bc")
@export var pupil_color := Color("172729")
var clock := 0.0
var look := 0.0
var hurt_amount := 0.0
var dead := false

func _ready() -> void:
	if z_index < 5:
		z_index = 5
	if not material:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/character/emissive_character.gdshader")
		material = mat

func sync_bone(head_bone: Bone2D, delta: float, look_direction: float) -> void:
	if is_instance_valid(head_bone):
		position = get_parent().to_local(head_bone.global_position)
	clock += delta
	look = lerpf(look, clampf(look_direction, -1, 1), 1.0 - exp(-delta * 12))
	queue_redraw()

func sync(rig: MudRig, delta: float, look_direction: float) -> void:
	if rig:
		position = rig.point(&"Head")
	clock += delta
	look = lerpf(look, clampf(look_direction, -1, 1), 1.0 - exp(-delta * 12))
	queue_redraw()

var death_alpha := 1.0
var death_melt := 0.0

func sync_death(death_progress: float, mode: int = 0) -> void:
	if death_progress <= 0.0:
		dead = false
		death_alpha = 1.0
		death_melt = 0.0
		return
		
	match mode:
		0: # SINK_AND_FADE
			hurt_amount = clampf(death_progress * 2.0, 0.0, 1.0)
			dead = death_progress > 0.30
			if death_progress > 0.65:
				death_alpha = clampf(1.0 - (death_progress - 0.65) / 0.25, 0.0, 1.0)
			else:
				death_alpha = 1.0
		1: # INSTANT_EXTINGUISH
			dead = true
			hurt_amount = 1.0
			death_alpha = 1.0 if death_progress < 0.7 else 0.0
		2: # MELT_INTO_PUDDLE
			dead = death_progress > 0.25
			hurt_amount = 1.0
			death_melt = clampf((death_progress - 0.25) / 0.55, 0.0, 1.0)
			death_alpha = clampf(1.0 - (death_progress - 0.70) / 0.20, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if death_alpha <= 0.001: return
	var closed := dead or fmod(clock, blink_interval) < blink_duration
	var h := 1.0 if closed else 3.0 * (1.0 - hurt_amount * 0.5)
	if death_melt > 0.0:
		h = maxf(1.0, h * (1.0 - death_melt))
	
	var ec := eye_color
	var pc := pupil_color
	if death_alpha < 1.0:
		ec.a = death_alpha
		pc.a = death_alpha
		
	draw_rect(Rect2(0, -3 + death_melt * 2.0, 2 + death_melt * 2.0, h), ec.darkened(0.18))
	draw_rect(Rect2(4, -3 + death_melt * 2.0, 4 + death_melt * 3.0, h + (0 if closed else 1)), ec)
	if not closed:
		draw_rect(Rect2(6 + look * 0.6, -2, 1, 2), pc)
		draw_rect(Rect2(1, -2, 1, 1), pc)

