extends SceneTree

const Modifier = preload("res://gameplay/character/sdf/sdf_modifier.gd")
const Profile = preload("res://gameplay/character/sdf/sdf_morph_profile.gd")
const PROFILE_PATHS := [
	"res://content/base/morphs/swollen_arm.tres",
	"res://content/base/morphs/hungry_ghost.tres",
	"res://content/base/morphs/asura_shoulder.tres",
	"res://content/base/morphs/hollow_face.tres",
	"res://content/base/morphs/spine_growth.tres",
]

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func vec4_xy(value: Vector4) -> Vector2:
	return Vector2(value.x, value.y)

func run() -> void:
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	root.add_child(actor)
	await process_frame
	actor.set_physics_process(false)
	actor.weapons.equip(null)
	var renderer: MudBodyRenderer = actor.body_renderer
	renderer.sync_skeleton(actor.skeleton)
	var collision_shape: Shape2D = actor.get_node("CollisionShape2D").shape
	var baseline_segment_count := renderer.segment_cursor
	var baseline_leg_radius := renderer.segments[0].radius_start
	var baseline_arm_radius := renderer.segments[6].radius_start
	var baseline_torso_radius := renderer.segments[11].radius_start
	var baseline_head_radius := renderer.segments[15].radius_start
	var renderer_child_count := renderer.get_child_count()

	check(renderer.active_morph_profile_count() == 0, "Base anatomy starts without active morph profiles")
	check(renderer.active_modifier_count() == 0 and renderer.resolved_modifier_count == 0, "Base anatomy uploads zero SDF modifiers")
	check(int(renderer.shader_material.get_shader_parameter("modifier_count")) == 0, "Shader receives an empty modifier array for the unmodified body")

	var profiles: Array[Resource] = []
	for path in PROFILE_PATHS:
		var profile := load(path)
		profiles.append(profile)
		check(profile != null, "Development morph profile loads: " + path.get_file())

	var swollen = profiles[0]
	renderer.apply_morph_profile(swollen)
	renderer.sync_skeleton(actor.skeleton)
	check(renderer.active_morph_profile_count() == 1 and renderer.resolved_modifier_count == 1, "Runtime can apply one morph profile")
	check(int(round(renderer.modifier_meta[0].x)) == Modifier.Operation.ADD, "SwollenArm uploads an ADD operation")
	check(int(round(renderer.modifier_meta[0].y)) == Modifier.Shape.CAPSULE, "SwollenArm uploads a capsule shape")
	check(is_equal_approx(renderer.modifier_meta[0].z, 1.0), "SwollenArm remains on the front depth pass")
	check(vec4_xy(renderer.modifier_a[0]).distance_to(renderer.point(&"ArmFrontJoint")) < 0.01, "Capsule start follows ArmFrontJoint")
	check(vec4_xy(renderer.modifier_b[0]).distance_to(renderer.point(&"ArmFrontEnd")) < 0.01, "Capsule end follows ArmFrontEnd")
	var old_end := vec4_xy(renderer.modifier_b[0])
	actor._forearm_front_bone.rotation += 0.45
	renderer.sync_skeleton(actor.skeleton)
	check(vec4_xy(renderer.modifier_b[0]).distance_to(old_end) > 2.0, "Forearm modifier follows animated bone rotation")
	check(actor.get_node("CollisionShape2D").shape == collision_shape, "Morph application does not replace or edit the collision shape")

	renderer.remove_morph_profile(swollen)
	renderer.sync_skeleton(actor.skeleton)
	check(renderer.active_modifier_count() == 0 and renderer.resolved_modifier_count == 0, "Runtime can remove a morph profile")

	for profile in profiles:
		renderer.apply_morph_profile(profile)
	renderer.apply_morph_profile(swollen)
	renderer.sync_skeleton(actor.skeleton)
	check(renderer.active_morph_profile_count() == 5, "Applying the same profile twice is idempotent")
	check(renderer.active_modifier_count() == 9 and renderer.resolved_modifier_count == 9, "Five development profiles stack into nine cached modifiers")
	var add_count := 0
	var subtract_count := 0
	for i in renderer.resolved_modifier_count:
		if int(round(renderer.modifier_meta[i].x)) == Modifier.Operation.ADD:
			add_count += 1
		else:
			subtract_count += 1
	check(add_count == 7 and subtract_count == 2, "Stack preserves seven ADD and two SUBTRACT operations")
	check(int(renderer.shader_material.get_shader_parameter("modifier_count")) == 9, "Body material receives the complete modifier upload")
	for material in renderer.depth_materials:
		check(int(material.get_shader_parameter("modifier_count")) == 9, "Rear and front materials share the body modifier upload")
	check(actor.eyes.visible and not renderer.is_ancestor_of(actor.eyes), "HollowFace leaves the independent Eyes renderer intact")

	renderer.modifier_debug_draw = true
	renderer.sync_skeleton(actor.skeleton)
	check(renderer.get_node("ModifierDebugOverlay").visible, "F1 modifier debug overlay can be shown")
	check(renderer.get_child_count() == renderer_child_count, "Debug and morph sync do not create per-modifier nodes")
	renderer.modifier_debug_draw = false

	renderer.clear_morph_profiles()
	var scale_profile := Profile.new()
	scale_profile.id = &"ScaleAndColorTest"
	scale_profile.body_radius_multiplier = 1.2
	scale_profile.head_radius_multiplier = 0.8
	scale_profile.arm_radius_multiplier = 1.1
	scale_profile.leg_radius_multiplier = 0.9
	scale_profile.mud_color_override_enabled = true
	scale_profile.mud_color = Color("8d4f72")
	renderer.apply_morph_profile(scale_profile)
	renderer.sync_skeleton(actor.skeleton)
	check(is_equal_approx(renderer.segments[11].radius_start, baseline_torso_radius * 1.2), "Body radius multiplier affects base torso anatomy")
	check(is_equal_approx(renderer.segments[15].radius_start, baseline_head_radius * 0.8), "Head radius multiplier affects base head anatomy")
	check(is_equal_approx(renderer.segments[6].radius_start, baseline_arm_radius * 1.1), "Arm radius multiplier affects base arm anatomy")
	check(is_equal_approx(renderer.segments[0].radius_start, baseline_leg_radius * 0.9), "Leg radius multiplier affects base leg anatomy")
	check(Color(renderer.shader_material.get_shader_parameter("mud_color")).is_equal_approx(scale_profile.mud_color), "Last enabled profile color override reaches the shader")
	renderer.clear_morph_profiles()
	renderer.sync_skeleton(actor.skeleton)
	check(renderer.segment_cursor == baseline_segment_count, "Clearing morphs restores the original base segment topology")
	check(is_equal_approx(renderer.segments[11].radius_start, baseline_torso_radius), "Clearing morphs restores the original body radius")
	check(Color(renderer.shader_material.get_shader_parameter("mud_color")).is_equal_approx(renderer.mud_color), "Clearing morphs restores the base mud color")

	var crowd: Array[MudCharacter] = []
	var crowd_ok := true
	for i in 30:
		var member := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		member.player_controlled = false
		root.add_child(member)
		member.set_physics_process(false)
		member.body_renderer.apply_morph_profile(profiles[0])
		member.body_renderer.apply_morph_profile(profiles[1])
		member.body_renderer.sync_skeleton(member.skeleton)
		crowd_ok = crowd_ok and member.body_renderer.resolved_modifier_count == 2
		crowd_ok = crowd_ok and member.body_renderer.segment_cursor <= MudBodyRenderer.MAX_SEGMENTS
		crowd.append(member)
	check(crowd_ok, "30 simultaneous mutated bodies stay within cached segment and modifier capacities")

	for member in crowd:
		member.queue_free()
	actor.queue_free()
	await process_frame
	print("SDF MORPH RESULT: ", failures, " failures")
	quit(1 if failures else 0)
