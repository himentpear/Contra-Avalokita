extends SceneTree

const WILE := preload("res://content/base/items/coyote/wile_glance.tres")
const ABSURD := preload("res://content/base/items/coyote/suspended_absurdity.tres")
const HERMES := preload("res://content/base/items/coyote/hermes_winged_boots.tres")
const GRAVITY_ITEM := preload("res://content/base/items/coyote/dear_cruel_gravity.tres")
const PARDON := preload("res://content/base/items/coyote/three_eyed_pardon.tres")

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func near(a: float, b: float, epsilon := 0.001) -> bool:
	return absf(a-b) <= epsilon

func apply_items(assist: MudMovementAssist, items: Array[CoyoteItem]) -> MudItemInventory:
	var inventory := MudItemInventory.new()
	for item in items: inventory.obtain(item)
	assist.apply_modifiers(inventory.aggregate_movement_modifiers())
	return inventory

func run() -> void:
	var assist := MudMovementAssist.new()
	assist.configure(0.10, 0.08)

	# A: edge-triggered input on ground resolves once as a normal ground jump.
	assist.reset(true)
	assist.register_jump_input()
	var source := assist.resolve_jump_source(true)
	check(source == MudMovementAssist.JumpSource.GROUND, "A default ground jump resolves as GROUND")
	assist.consume_jump(source)
	check(not assist.has_buffered_jump(), "A ground jump consumes its input exactly once")

	# B/C: natural ledge departure creates a finite UNFALLEN permission.
	assist.reset(true)
	assist.observe_grounded(false)
	assist.advance(0.05, false)
	assist.register_jump_input()
	check(assist.resolve_jump_source(false) == MudMovementAssist.JumpSource.COYOTE, "B jump succeeds about 0.05 seconds after ledge departure")
	assist.reset(true)
	assist.observe_grounded(false)
	assist.advance(0.101, false)
	assist.register_jump_input()
	check(assist.resolve_jump_source(false) == MudMovementAssist.JumpSource.NONE, "C expired 0.10 second Coyote permission rejects jump")

	# D: the ground jump departure is explicitly suppressed, so no double jump.
	assist.reset(true)
	assist.register_jump_input()
	source = assist.resolve_jump_source(true)
	assist.consume_jump(source)
	assist.observe_grounded(false)
	assist.advance(0.05, false)
	assist.register_jump_input()
	check(assist.resolve_jump_source(false) == MudMovementAssist.JumpSource.NONE, "D ground jump cannot manufacture a second Coyote jump")

	# E: an older airborne input resolves as buffered when landing occurs.
	assist.reset(false)
	assist.register_jump_input()
	assist.finish_step()
	assist.advance(0.05, false)
	assist.observe_grounded(true)
	check(assist.resolve_jump_source(true) == MudMovementAssist.JumpSource.BUFFERED_GROUND, "E pre-landing input resolves as BUFFERED_GROUND")

	# F/J/K plus removal: durations are additive and recomputed from immutable bases.
	assist.reset(false)
	var inventory := apply_items(assist, [WILE])
	check(near(assist.get_effective_coyote_time(), 0.16), "F Wile glance extends Coyote to 0.16 seconds")
	inventory.obtain(PARDON)
	assist.apply_modifiers(inventory.aggregate_movement_modifiers())
	check(near(assist.get_effective_coyote_time(), 0.20) and near(assist.get_effective_jump_buffer_time(), 0.13), "K Wile and pardon stack to 0.20 / 0.13 seconds")
	inventory.remove(WILE.id)
	assist.apply_modifiers(inventory.aggregate_movement_modifiers())
	check(near(assist.get_effective_coyote_time(), 0.14) and near(assist.get_effective_jump_buffer_time(), 0.13), "J removing Wile recomputes pardon values to 0.14 / 0.13")

	# I: gravity policy changes only during the first 0.06 seconds of UNFALLEN.
	assist.reset(true)
	apply_items(assist, [GRAVITY_ITEM])
	assist.observe_grounded(false)
	check(near(assist.get_gravity_multiplier(), 0.65), "I initial UNFALLEN gravity is 0.65")
	assist.advance(0.059, false)
	check(near(assist.get_gravity_multiplier(), 0.65), "I reduced gravity lasts through 0.06 seconds")
	assist.advance(0.002, false)
	check(near(assist.get_gravity_multiplier(), 1.0), "I gravity returns to 1.0 after initial window")

	# G/H/L: actual launch uses semantic source and is facing-independent.
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	root.add_child(actor)
	await process_frame
	actor.movement_assist.reset(true)
	actor.movement_assist.observe_grounded(false)
	var frozen_coyote := actor.movement_assist.get_coyote_remaining()
	actor.local_time_scale = 0.0
	await physics_frame
	check(near(actor.movement_assist.get_coyote_remaining(), frozen_coyote), "Local hit stop freezes movement-assist timers")
	actor.local_time_scale = 1.0
	actor.item_inventory.clear()
	actor.obtain_item(ABSURD)
	actor.obtain_item(HERMES)
	actor.velocity = Vector2(80.0, 0.0)
	actor.facing = 1.0
	actor.perform_jump(MudMovementAssist.JumpSource.COYOTE)
	var right_launch := actor.velocity
	check(near(right_launch.x, 89.6) and near(right_launch.y, actor.jump_velocity*1.10), "G/H Coyote launch applies +12% horizontal and +10% vertical")
	actor.velocity = Vector2(-80.0, 0.0)
	actor.facing = -1.0
	actor.perform_jump(MudMovementAssist.JumpSource.COYOTE)
	check(near(actor.velocity.x, -right_launch.x) and near(actor.velocity.y, right_launch.y), "L Coyote launch is symmetric for both facings")
	actor.velocity = Vector2(80.0, 0.0)
	actor.perform_jump(MudMovementAssist.JumpSource.GROUND)
	check(near(actor.velocity.x, 80.0) and near(actor.velocity.y, actor.jump_velocity), "G/H normal ground launch remains unchanged")

	# Content and UI use the existing registry definition shape and one reusable card.
	var manifest := load("res://content/base/manifest.tres") as ContentManifest
	var item_count := 0
	for definition: ContentDefinition in manifest.definitions:
		if definition.content_type == &"item": item_count += 1
	check(item_count >= 5, "Five Coyote item definitions are mounted by the base manifest")
	var gallery := preload("res://ui/items/coyote_item_gallery.tscn").instantiate()
	root.add_child(gallery)
	await process_frame
	check(gallery.get_child_count() == 5, "Five item windows display registered item data")

	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	gallery.queue_free()
	await process_frame
	print("MOVEMENT ASSIST RESULT: ", failures, " failures")
	quit(1 if failures else 0)
