extends SceneTree
## Creates the five development profiles used by the SDF morph test suite.

const Modifier = preload("res://gameplay/character/sdf/sdf_modifier.gd")
const Profile = preload("res://gameplay/character/sdf/sdf_morph_profile.gd")
const OUTPUT_DIRS := ["res://content/base/morphs", "res://resources/morphs"]

func _initialize() -> void:
	call_deferred("generate")

func modifier(
	id: StringName,
	operation: int,
	shape: int,
	anchor: StringName,
	anchor_b: StringName = &"",
	offset := Vector2.ZERO,
	radius := 4.0,
	radius_end := 4.0,
	length := 8.0,
	rotation := 0.0,
	softness := 1.0,
	depth := 0.0
) -> Resource:
	var result := Modifier.new()
	result.id = id
	result.operation = operation
	result.shape = shape
	result.anchor = anchor
	result.anchor_b = anchor_b
	result.local_offset = offset
	result.radius = radius
	result.radius_end = radius_end
	result.length = length
	result.rotation = rotation
	result.softness = softness
	result.depth = depth
	return result

func save_profile(file_name: String, id: StringName, items: Array[Resource]) -> Error:
	for output_dir in OUTPUT_DIRS:
		DirAccess.make_dir_recursive_absolute(output_dir)
		var profile: SdfMorphProfile = Profile.new()
		profile.id = id
		for item in items:
			profile.modifiers.append(item as SdfModifier)
		var err := ResourceSaver.save(profile, output_dir.path_join(file_name))
		if err != OK:
			return err
	return OK

func generate() -> void:
	for output_dir in OUTPUT_DIRS:
		DirAccess.make_dir_recursive_absolute(output_dir)
	var add := Modifier.Operation.ADD
	var subtract := Modifier.Operation.SUBTRACT
	var circle := Modifier.Shape.CIRCLE
	var capsule := Modifier.Shape.CAPSULE
	var results := [
		save_profile("swollen_arm.tres", &"SwollenArm", [
			modifier(&"SwollenForearm", add, capsule, &"ArmFrontJoint", &"ArmFrontEnd", Vector2.ZERO, 5.2, 4.8, 8.0, 0.0, 1.5, 1.0),
		]),
		save_profile("hungry_ghost.tres", &"HungryGhost", [
			modifier(&"OpenAbdomen", subtract, circle, &"Abdomen", &"", Vector2(0.0, -5.0), 6.0, 4.0, 8.0, 0.0, 1.1, 0.0),
		]),
		save_profile("asura_shoulder.tres", &"AsuraShoulder", [
			modifier(&"ShoulderMass", add, circle, &"ArmFrontStart", &"", Vector2(0.0, -2.5), 6.2, 4.0, 8.0, 0.0, 1.4, 1.0),
			modifier(&"ShoulderSpur", add, capsule, &"ArmFrontStart", &"", Vector2(0.0, -2.0), 3.2, 1.6, 9.0, -0.7, 1.0, 1.0),
		]),
		save_profile("hollow_face.tres", &"HollowFace", [
			modifier(&"FaceVoid", subtract, circle, &"Head", &"", Vector2.ZERO, 2.4, 4.0, 8.0, 0.0, 0.65, 0.0),
		]),
		save_profile("spine_growth.tres", &"SpineGrowth", [
			modifier(&"SpinePelvis", add, circle, &"Pelvis", &"", Vector2(0.0, -8.0), 2.6, 4.0, 8.0, 0.0, 0.8, -1.0),
			modifier(&"SpineAbdomen", add, circle, &"Abdomen", &"", Vector2(0.0, -8.5), 2.8, 4.0, 8.0, 0.0, 0.8, -1.0),
			modifier(&"SpineChest", add, circle, &"Torso", &"", Vector2(0.0, -8.5), 2.7, 4.0, 8.0, 0.0, 0.8, -1.0),
			modifier(&"SpineNeck", add, circle, &"Neck", &"", Vector2(0.0, -7.0), 2.2, 4.0, 8.0, 0.0, 0.7, -1.0),
		]),
	]
	for result in results:
		if result != OK:
			push_error("Failed to generate morph profile: %s" % error_string(result))
			quit(1)
			return
	print("Generated five SDF morph profiles in ", OUTPUT_DIRS)
	quit()
