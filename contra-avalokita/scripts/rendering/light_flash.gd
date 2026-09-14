class_name DynamicLightFlash
extends PointLight2D

@export var duration := 0.12
var elapsed := 0.0
var initial_energy := 2.5

func _ready() -> void:
	initial_energy = energy

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	var p := clampf(elapsed / duration, 0.0, 1.0)
	energy = initial_energy * (1.0 - p)
