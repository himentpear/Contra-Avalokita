extends SceneTree

class TestLayer extends AnimationLayer:
	var update_count := 0
	var last_delta := 0.0
	var last_context: AnimationContext

	func update(delta: float, context: AnimationContext) -> void:
		update_count += 1
		last_delta = delta
		last_context = context

class SnapshotProvider extends AnimationContextProvider:
	var snapshot := AnimationContext.new()

	func build_context() -> AnimationContext:
		return snapshot

class MockMovement extends Node:
	var facing := -1.0
	var move_intent := 1.0
	var move_speed := 100.0
	var jump_phase: StringName = &"Grounded"
	var wall_action: StringName = &"None"
	var jump_squat_left := 0.0
	var air_time := 0.0
	var takeoff_duration := 0.075
	var apex_threshold := 35.0
	var landing_left := 0.0
	var landing_recovery_duration := 0.07
	var grounded_resume_phase := 0.25

class MockState extends Node:
	var locomotion_state: StringName = &"Run"
	var action_state: StringName = &"Attack2"
	var reaction_state: StringName = &"None"

class MockCombat extends Node:
	var combo_stage := 1
	var reaction_direction := Vector2.LEFT
	var reaction_intensity := 0.5

class MockWeapon extends Node:
	var weapon_class: StringName = &"blade"

class MockEquipment extends Node:
	var current: MockWeapon

	func is_armed() -> bool:
		return current != null

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
	_test_pure_context()
	_test_mud_provider()
	_test_profile_and_manager_protocol()
	_test_architecture_guards()
	await process_frame
	print("ANIMATION LAYER MANAGER RESULT: ", failures, " failures")
	quit(1 if failures else 0)

func _test_pure_context() -> void:
	var context := AnimationContext.new()
	var property_names: Array[StringName] = []
	for descriptor in context.get_property_list():
		property_names.append(StringName(descriptor.name))
	check(not property_names.has(&"character") and not property_names.has(&"animation_player") and not property_names.has(&"skeleton"), "AnimationContext contains no scene or renderer references")
	context.locomotion_state = &"Run"
	context.tags[&"test"] = true
	check(context.locomotion_state == &"Run" and context.get_value(&"test"), "AnimationContext is constructible as pure semantic data")

func _test_mud_provider() -> void:
	var body := CharacterBody2D.new()
	body.velocity = Vector2(80.0, 0.0)
	var movement := MockMovement.new()
	var state := MockState.new()
	var combat := MockCombat.new()
	var equipment := MockEquipment.new()
	equipment.current = MockWeapon.new()
	var provider := MudAnimationContextProvider.new().configure(body, movement, state, combat, equipment)
	provider.grounded_override = true
	var context := provider.build_context()
	check(context.locomotion_state == &"Run" and context.grounded, "Mud provider snapshots locomotion and grounded state")
	check(context.weapon_class == &"blade" and context.attack_stage == 1, "Mud provider describes blade combo stage one without clip names")
	check(context.get_value(&"locomotion_variant") == &"Backstep", "Mud provider expresses retreat as a semantic locomotion variant")
	provider.queue_free()
	body.free()
	movement.free()
	state.free()
	combat.free()
	equipment.current.free()
	equipment.free()

func _test_profile_and_manager_protocol() -> void:
	var profile := load("res://characters/mud/animation/mud_animation_profile.tres") as CharacterAnimationProfile
	var snapshot := AnimationContext.new()
	snapshot.locomotion_state = &"Run"
	snapshot.weapon_class = &"blade"
	snapshot.attack_stage = 1
	snapshot.wall_action = &"Hang"
	check(profile.resolve_locomotion(snapshot) == &"Run", "Mud profile resolves Run to the existing Run clip")
	check(profile.resolve_combat(snapshot) == &"Blade/Attack_2", "Mud profile resolves blade combo stage one")
	check(profile.resolve_wall(snapshot) == &"Wall/Hang", "Mud profile resolves wall Hang")

	var provider := SnapshotProvider.new()
	provider.snapshot = snapshot
	var manager := AnimationLayerManager.new()
	root.add_child(manager)
	manager.setup(provider, profile, AnimationBinding.new())
	var locomotion := TestLayer.new()
	locomotion.priority = 10
	locomotion.play(&"Run")
	check(manager.register_layer(locomotion), "Locomotion layer registers with the generic manager")
	var combat := TestLayer.new()
	combat.priority = 20
	combat.play(&"Attack")
	check(manager.register_layer(combat), "Combat layer registers with the generic manager")
	manager.update_layers(0.25)
	check(locomotion.update_count == 1 and combat.update_count == 1, "Manager updates every layer from provider snapshots")
	check(is_equal_approx(combat.last_delta, 0.25) and combat.last_context == snapshot, "Layers receive only delta and AnimationContext")
	check(manager.get_dominant_layer() == combat, "Highest-priority active layer is dominant")
	combat.weight = 0.0
	check(manager.get_dominant_layer() == locomotion, "Zero-weight layers do not participate in output selection")

	var creature := CharacterAnimationProfile.new()
	creature.character_id = &"test_creature"
	creature.locomotion = {&"Run": &"Scuttle"}
	creature.combat = {&"claw.attack.0": &"Bite"}
	snapshot.weapon_class = &"claw"
	snapshot.attack_stage = 0
	manager.setup(provider, creature, AnimationBinding.new())
	check(manager.resolve_locomotion() == &"Scuttle" and manager.resolve_combat() == &"Bite", "The same manager resolves a second character profile without type branches")
	manager.queue_free()

func _test_architecture_guards() -> void:
	var shared_files := [
		"res://scripts/components/animation/animation_context.gd",
		"res://scripts/components/animation/animation_context_provider.gd",
		"res://scripts/components/animation/animation_binding.gd",
		"res://scripts/components/animation/character_animation_profile.gd",
		"res://scripts/components/animation/animation_layer.gd",
		"res://scripts/components/animation/animation_layer_manager.gd",
	]
	var forbidden := ["MudCharacter", "mud_character", "owner_character", "context.character", " is Player", " is Enemy", " is Boss"]
	var clean := true
	for path in shared_files:
		var source := FileAccess.get_file_as_string(path)
		for token in forbidden:
			if token in source:
				clean = false
				push_error("Shared animation dependency guard: %s contains %s" % [path, token])
	check(clean, "Shared animation infrastructure has no concrete character dependencies")
