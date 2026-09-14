extends SceneTree

const CATALOG_PATH := "res://addons/rotobone/v3/presets/asset_action_catalog.json"
const OUTPUT_PATH := "res://addons/rotobone/v3/presets/asset_action_placeholders.tres"
const TEMPLATE_PATH := "res://scenes/mud_character.tscn"
const FPS := 12.0
const LOOP_ACTIONS := [
	"Crouch-Idle", "Crouch-Walk", "Idle", "Katana Run", "Katana walk",
	"PushPull (idle state)", "Run", "Shooting (running and aiming)",
	"Sword Idle", "Sword Run", "Walk", "Wall Slide",
]


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not catalog is Dictionary:
		_fail("Cannot parse asset action catalog")
		return
	var packed := load(TEMPLATE_PATH) as PackedScene
	if packed == null:
		_fail("Cannot load mud_character template")
		return
	var mud := packed.instantiate()
	mud.name = "MudCharacterInstance"
	mud.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(mud)
	var source_player := _find_type(mud, "AnimationPlayer") as AnimationPlayer
	var skeleton := _find_type(mud, "Skeleton2D") as Skeleton2D
	if source_player == null or skeleton == null:
		_fail("Template AnimationPlayer or Skeleton2D not found")
		return
	var bones := _collect_bones(skeleton)
	var base_rotations: Array[float] = []
	for bone in bones:
		base_rotations.append(bone.rotation)

	var library := AnimationLibrary.new()
	for action in catalog.get("actions", []):
		if not action is Dictionary:
			continue
		var animation := _build_animation(action, mud, source_player, skeleton, bones, base_rotations)
		library.add_animation(StringName(action.get("folder", "Unnamed")), animation)
	var error := ResourceSaver.save(library, OUTPUT_PATH)
	if error != OK:
		_fail("Cannot save placeholder library: %s" % error_string(error))
		return
	print("Built %d AssetActions animations with frame markers and smooth Bone2D rotation keys" % library.get_animation_list().size())
	root.remove_child(mud)
	mud.free()
	quit(0)


func _build_animation(
	action: Dictionary,
	mud: Node,
	source_player: AnimationPlayer,
	skeleton: Skeleton2D,
	bones: Array[Bone2D],
	base_rotations: Array[float]
) -> Animation:
	var animation := Animation.new()
	var folder := String(action.get("folder", "Unnamed"))
	animation.resource_name = folder
	animation.step = 1.0 / FPS
	animation.loop_mode = Animation.LOOP_LINEAR if LOOP_ACTIONS.has(folder) else Animation.LOOP_NONE
	var texture := load(String(action.get("reference_sprite", ""))) as Texture2D
	var frame_width := maxi(1, int(action.get("frame_width", 48)))
	var frame_height := maxi(1, int(action.get("frame_height", 48)))
	var frame_count := 1
	if texture != null:
		frame_count = maxi(1, (texture.get_width() / frame_width) * (texture.get_height() / frame_height))
	animation.length = frame_count / FPS

	var tracks: Array[int] = []
	for bone in bones:
		var track := animation.add_track(Animation.TYPE_VALUE)
		var path := NodePath("MudCharacterInstance/%s:rotation" % String(mud.get_path_to(bone)))
		animation.track_set_path(track, path)
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC_ANGLE)
		tracks.append(track)

	var source_name := StringName(action.get("source_animation", ""))
	var has_source := not source_name.is_empty() and source_player.has_animation(source_name)
	var source_length := source_player.get_animation(source_name).length if has_source else 0.0
	for frame_index in frame_count:
		_restore_rotations(bones, base_rotations)
		if has_source:
			var divisor := float(frame_count) if animation.loop_mode == Animation.LOOP_LINEAR else float(maxi(1, frame_count - 1))
			var source_time := minf(source_length, frame_index / divisor * source_length)
			source_player.play(source_name)
			source_player.seek(source_time, true)
			source_player.pause()
		var key_time := frame_index / FPS
		animation.add_marker(StringName("F%02d" % (frame_index + 1)), key_time)
		for bone_index in bones.size():
			animation.track_insert_key(tracks[bone_index], key_time, bones[bone_index].rotation)
	_restore_rotations(bones, base_rotations)
	return animation


func _restore_rotations(bones: Array[Bone2D], rotations: Array[float]) -> void:
	for index in bones.size():
		bones[index].rotation = rotations[index]


func _collect_bones(skeleton: Skeleton2D) -> Array[Bone2D]:
	var bones: Array[Bone2D] = []
	_collect_bones_recursive(skeleton, bones)
	return bones


func _collect_bones_recursive(node: Node, bones: Array[Bone2D]) -> void:
	for child in node.get_children():
		if child is Bone2D:
			bones.append(child as Bone2D)
		_collect_bones_recursive(child, bones)


func _find_type(node: Node, type_name: StringName) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_type(child, type_name)
		if found != null:
			return found
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
