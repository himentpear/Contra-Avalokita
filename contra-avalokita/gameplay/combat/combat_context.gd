class_name CombatContext
extends Node

var actors: Array[Node] = []

func register_actor(actor: Node) -> void:
	if is_instance_valid(actor) and not actors.has(actor):
		actors.append(actor)

func unregister_actor(actor: Node) -> void:
	actors.erase(actor)

