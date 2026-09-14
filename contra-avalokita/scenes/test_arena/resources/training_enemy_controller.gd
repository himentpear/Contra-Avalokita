class_name TrainingEnemyController
extends Node

@export var detection_range := 230.0
@export var attack_range := 34.0
@export var retreat_range := 18.0
@export var attack_cooldown := 0.85
var actor: MudCharacter
var target: MudCharacter
var cooldown := 0.25

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(target): return
	if actor.state == &"Dead" or target.state == &"Dead":
		actor.set_intent(0.0)
		return
	cooldown = maxf(0.0, cooldown-delta)
	var offset := target.global_position-actor.global_position
	if absf(offset.x) > detection_range:
		actor.set_intent(0.0)
		return
	var direction := signf(offset.x)
	if absf(offset.x) > attack_range:
		actor.set_intent(direction)
	elif absf(offset.x) < retreat_range:
		actor.set_intent(-direction*0.35)
	elif cooldown <= 0.0 and not actor.is_attacking():
		actor.facing = direction
		actor.set_intent(0.0, false, true)
		cooldown = attack_cooldown
	else:
		actor.set_intent(0.0)
