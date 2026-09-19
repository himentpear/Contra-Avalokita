class_name TrainingEnemyController
extends Node

@export var detection_range := 230.0
@export var attack_range := 34.0
@export var retreat_range := 18.0
@export var attack_cooldown := 0.85
@export var separation_radius := 40.0
@export var separation_force := 6.0
@export var target_path: NodePath
var actor: MudCharacter
var target: MudCharacter
var cooldown := 0.25

func _ready() -> void:
	if not is_instance_valid(actor):
		actor = get_parent() as MudCharacter
	if not is_instance_valid(target) and not target_path.is_empty():
		target = get_node_or_null(target_path) as MudCharacter

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
	var separation := 0.0
	var container := actor.get_parent()
	if is_instance_valid(container):
		for sibling in container.get_children():
			var other := sibling as MudCharacter
			if other == actor or not is_instance_valid(other) or not other.is_in_group(&"training_enemy"):
				continue
			var gap := actor.global_position.x - other.global_position.x
			if absf(gap) < separation_radius:
				var away := signf(gap) if absf(gap) > 0.01 else (1.0 if actor.get_instance_id() > other.get_instance_id() else -1.0)
				separation += away * (1.0 - absf(gap) / separation_radius)
	if absf(offset.x) > attack_range:
		actor.set_intent(clampf(direction + separation * separation_force, -1.0, 1.0))
	elif absf(offset.x) < retreat_range:
		actor.set_intent(clampf(-direction * 0.35 + separation * separation_force, -1.0, 1.0))
	elif cooldown <= 0.0 and not actor.is_attacking():
		actor.facing = direction
		actor.set_intent(0.0, false, true)
		cooldown = attack_cooldown
	else:
		actor.set_intent(clampf(separation * separation_force, -1.0, 1.0))
