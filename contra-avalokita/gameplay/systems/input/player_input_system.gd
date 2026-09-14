extends Node

## ECS phase-1 input adapter. It owns all MudCharacter player Input polling and
## forwards sampled intent through the same set_intent() API used by enemy AI.
const INPUT_ENTITY_GROUP := &"player_input_entities"

func _physics_process(_delta: float) -> void:
	for candidate: Node in get_tree().get_nodes_in_group(INPUT_ENTITY_GROUP):
		_poll_entity(candidate)

func _poll_entity(actor: Node) -> void:
	if not is_instance_valid(actor) or not actor.is_node_ready():
		return
	if actor.get("player_controlled") != true or actor.get("state") == &"Dead":
		return
	# Preserve the legacy behavior: input was not sampled while local hitstop
	# returned early from MudCharacter._physics_process().
	if float(actor.get("local_time_scale")) <= 0.0:
		return
	if not actor.has_method("set_intent"):
		return

	var intent := actor.get("intent_component") as IntentComponent
	if intent == null:
		return

	intent.move_direction = Input.get_axis("move_left", "move_right")
	intent.sprint_held = Input.is_action_pressed("sprint")
	if not intent.sprint_held:
		intent.move_direction *= float(actor.get("walk_speed_ratio"))
	intent.jump_pressed = Input.is_action_just_pressed("jump")
	intent.attack_pressed = Input.is_action_just_pressed("attack")
	intent.block_held = Input.is_action_pressed("block") if InputMap.has_action("block") else false
	intent.equipment_toggle_pressed = Input.is_action_just_pressed("equipment")
	intent.equip_sword_pressed = Input.is_action_just_pressed("weapon_sword")
	intent.unequip_weapon_pressed = Input.is_action_just_pressed("weapon_none")
	intent.debug_rig_pressed = Input.is_action_just_pressed("debug_rig")

	actor.call(
		"set_intent",
		intent.move_direction,
		intent.jump_pressed,
		intent.attack_pressed,
		intent.block_held
	)
	_apply_transitional_actions(actor, intent)

func _apply_transitional_actions(actor: Node, intent: IntentComponent) -> void:
	# These are input routing operations moved verbatim from MudCharacter. Their
	# equipment, combat, animation and debug implementations are not changed.
	var equipment = actor.get("equipment")
	if intent.equipment_toggle_pressed and is_instance_valid(equipment):
		equipment.call("toggle")

	var weapons = actor.get("weapons")
	if not bool(actor.call("is_attacking")) and is_instance_valid(weapons):
		if intent.equip_sword_pressed:
			weapons.call("equip", weapons.get("default_weapon"))
			actor.call("sync_weapon_animation")
		if intent.unequip_weapon_pressed:
			weapons.call("equip", null)
			actor.call("sync_weapon_animation")

	if intent.debug_rig_pressed:
		var rig = actor.get("rig")
		var body_renderer = actor.get("body_renderer")
		if rig != null:
			rig.debug_draw = not rig.debug_draw
			if is_instance_valid(body_renderer):
				body_renderer.modifier_debug_draw = rig.debug_draw
