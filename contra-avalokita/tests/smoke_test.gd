extends SceneTree
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func ticks(count: int) -> void:
	for i in count: await physics_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena := load("res://scenes/test_arena.tscn").instantiate() as Node2D
	root.add_child(arena)
	var p: MudCharacter = arena.player
	p.player_controlled = false
	await ticks(12)
	check(p.is_on_floor() and p.state == &"Idle", "Stable capsule lands and idles")
	p.player_controlled = true
	Input.action_press("move_right")
	await ticks(20)
	check(p.state == &"Walk" and absf(p.velocity.x - p.move_speed * p.walk_speed_ratio) < 0.1, "Default movement selects Walk")
	Input.action_press("sprint")
	await ticks(12)
	check(p.state == &"Run", "Holding Shift selects Run")
	Input.action_release("move_right")
	Input.action_release("sprint")
	p.player_controlled = false
	var start_x := p.position.x
	p.set_intent(1)
	await ticks(20)
	check(p.position.x > start_x + 15 and p.state == &"Run", "Run accelerates and changes pose")
	p.set_intent(-1)
	await ticks(8)
	check(p.facing == -1 and p.visual.scale.x == -1, "Facing mirrors rig, equipment and weapon")
	p.set_intent(0, true)
	await ticks(9)
	check(p.state == &"Jump" and p.velocity.y < 0, "Jump leaves floor")
	await ticks(65)
	check(p.is_on_floor(), "Jump returns to stable collision")
	p.position = Vector2(370, 136)
	p.facing = 1
	p.velocity = Vector2.ZERO
	p.set_intent(0)
	await ticks(4)
	var initial_hits: int = arena.dummy.hit_count
	p.set_intent(0, false, true)
	await ticks(2)
	check(p.is_attacking() and p.state == &"Idle", "Attack overlays independent movement state")
	check(not p.weapons.current.active, "Windup has no damage")
	await ticks(2)
	check(p.rig.compressions["ArmFront"] > 0.3, "Windup folds elbow and activates soft joint compression")
	await ticks(38)
	check(p.state == &"Idle" and not p.weapons.current.active, "Recovery closes hitbox")
	check(arena.dummy.hit_count == initial_hits + 1, "Sword hits dummy exactly once per swing")
	p.set_intent(0, false, true)
	await ticks(42)
	check(arena.dummy.hit_count == initial_hits + 2, "Next swing resets hit deduplication")
	var count := p.rig.segments.size()
	p.equipment.toggle()
	p.weapons.equip(null)
	await ticks(3)
	check(p.rig.segments.size() == count and p.weapons.current == null, "Removing equipment/weapon preserves body topology")
	p.weapons.equip(p.weapons.default_weapon)
	check(p.weapons.current != null, "Weapon can be re-equipped")
	check(p.rig.point(&"ArmFrontPre").is_finite(), "Auxiliary points are finite")
	check(MudJointSolver.compression_for(deg_to_rad(20)) == 0.0, "Shallow joint stays uncompressed")
	check(MudJointSolver.compression_for(deg_to_rad(140)) > 0.99, "Deep joint compression saturates")
	var a := MudJointSolver.new()
	var b := MudJointSolver.new()
	a.step(Vector2.ZERO, 0)
	b.step(Vector2.ZERO, 0)
	for i in 60: a.step(Vector2(1, 0), 1.0 / 60.0)
	for i in 30: b.step(Vector2(1, 0), 1.0 / 30.0)
	check(a.current_position.distance_to(b.current_position) < 0.001, "Spring is consistent at 30/60 Hz")
	arena.cycle_crowd()
	arena.cycle_crowd()
	await ticks(120)
	check(arena.crowd.size() + 1 == 30, "30 independent rigs run without capacity errors")
	print("SMOKE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
