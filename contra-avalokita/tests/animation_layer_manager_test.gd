extends SceneTree

class TestLayer extends AnimationLayer:
	var update_count := 0
	var last_delta := 0.0
	var last_context: AnimationContext

	func update(delta: float, context: AnimationContext) -> void:
		update_count += 1
		last_delta = delta
		last_context = context

class ContextCharacter extends CharacterBody2D:
	var state: StringName = &"Run"
	var action_state: StringName = &"Attack"
	var reaction_state: StringName = &"LightHit"
	var facing := -1.0

	func is_armed() -> bool:
		return true

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	var character := ContextCharacter.new()
	root.add_child(character)
	var animation_player := AnimationPlayer.new()
	character.add_child(animation_player)
	var controller := AnimationController.new()
	character.add_child(controller)
	controller.setup(character, animation_player)
	check(controller.layer_manager != null and controller.layer_manager.context.character == character, "AnimationController owns a configured layer manager")

	var manager := AnimationLayerManager.new()
	root.add_child(manager)
	manager.setup(character)
	check(manager.context.locomotion_state == &"Run" and manager.context.action_state == &"Attack" and manager.context.reaction_state == &"LightHit", "Context snapshots locomotion, action, and reaction state")
	check(manager.context.facing == -1.0 and manager.context.armed, "Context snapshots presentation-facing character data")

	var locomotion := TestLayer.new()
	locomotion.name = "LocomotionLayer"
	locomotion.priority = 10
	locomotion.play(&"Run")
	check(manager.register_layer(locomotion), "Locomotion layer registers with the manager")

	var combat := TestLayer.new()
	combat.name = "CombatLayer"
	combat.priority = 20
	combat.play(&"Attack")
	check(manager.register_layer(combat), "Combat layer registers with the manager")

	manager.update_layers(0.25)
	check(locomotion.update_count == 1 and combat.update_count == 1, "Manager updates every registered layer")
	check(is_equal_approx(combat.last_delta, 0.25) and combat.last_context == manager.context, "Layers receive delta and shared animation context")
	check(manager.get_dominant_layer() == combat, "Highest-priority active layer is dominant")

	combat.weight = 0.0
	check(manager.get_dominant_layer() == locomotion, "Zero-weight layers do not participate in output selection")
	locomotion.weight = 2.0
	check(is_equal_approx(locomotion.weight, 1.0), "Layer weight is clamped to the mixer range")
	check(manager.unregister_layer(combat) and combat.get_parent() == null, "Layer unregisters without being freed")

	combat.free()
	manager.queue_free()
	character.queue_free()
	await process_frame
	print("ANIMATION LAYER MANAGER RESULT: ", failures, " failures")
	quit(1 if failures else 0)
