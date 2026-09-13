extends SceneTree
## One-shot, idempotent scene migration. Bone2D.rest is the sole reference source.
const SCENE_PATH := "res://scenes/mud_character.tscn"
const OLD_PREFIX := "Visual/Skeleton2D"
const NEW_PREFIX := "Visual/PoseRoot/Skeleton2D"
const POSE_ROOT_POSITION := NodePath("Visual/PoseRoot:position")
const PELVIS_POSITION := NodePath("Visual/PoseRoot/Skeleton2D/Pelvis:position")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	var character := packed.instantiate()
	var visual := character.get_node("Visual") as Node2D
	var pose_root := visual.get_node_or_null("PoseRoot") as Node2D
	var skeleton := visual.get_node_or_null("Skeleton2D") as Skeleton2D
	if not pose_root:
		pose_root = Node2D.new()
		pose_root.name = "PoseRoot"
		visual.add_child(pose_root)
		pose_root.owner = character
	if skeleton:
		skeleton.owner = null
		skeleton.reparent(pose_root,false)
		skeleton.owner = character
	else:
		skeleton = pose_root.get_node("Skeleton2D") as Skeleton2D
	var player := character.get_node("AnimationPlayer") as AnimationPlayer
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		for animation_name in library.get_animation_list():
			if animation_name != &"RESET": _migrate_animation(library.get_animation(animation_name))
		if not library.resource_path.is_empty():
			ResourceSaver.save(library,library.resource_path)
	for bone in skeleton.find_children("*","Bone2D",true,false):
		bone.transform = bone.rest
	pose_root.transform = Transform2D.IDENTITY
	var root_library := player.get_animation_library(&"")
	if root_library.has_animation(&"RESET"): root_library.remove_animation(&"RESET")
	root_library.add_animation(&"RESET",_build_reset(character,pose_root,skeleton))
	var validator := character.get_node_or_null("PoseValidation")
	if not validator:
		validator = Node.new()
		validator.name = "PoseValidation"
		character.add_child(validator)
		validator.owner = character
	validator.set_script(preload("res://scripts/mud_pose_reference_validator.gd"))
	var output := PackedScene.new()
	var pack_error := output.pack(character)
	assert(pack_error == OK,"Could not pack repaired MudCharacter")
	var save_error := ResourceSaver.save(output,SCENE_PATH)
	assert(save_error == OK,"Could not save repaired MudCharacter")
	print("[PoseValidation] Repaired canonical pose, migrated PoseRoot tracks, created complete RESET")
	character.free()
	quit()

func _migrate_animation(animation: Animation) -> void:
	var pelvis_track := -1
	for track in animation.get_track_count():
		var path_text := String(animation.track_get_path(track))
		if path_text.begins_with(OLD_PREFIX):
			animation.track_set_path(track,NodePath(path_text.replace(OLD_PREFIX,NEW_PREFIX)))
		if animation.track_get_path(track) == PELVIS_POSITION: pelvis_track = track
	var root_track := animation.find_track(POSE_ROOT_POSITION,Animation.TYPE_VALUE)
	var needs_split := root_track < 0
	if root_track < 0:
		root_track = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(root_track,POSE_ROOT_POSITION)
	if pelvis_track >= 0 and needs_split:
		animation.track_set_interpolation_type(root_track,animation.track_get_interpolation_type(pelvis_track))
		animation.track_set_interpolation_loop_wrap(root_track,animation.track_get_interpolation_loop_wrap(pelvis_track))
		for key in animation.track_get_key_count(pelvis_track):
			var value: Vector2 = animation.track_get_key_value(pelvis_track,key)
			animation.track_set_key_value(pelvis_track,key,Vector2(0.0,value.y))
			animation.track_insert_key(root_track,animation.track_get_key_time(pelvis_track,key),Vector2(value.x,0.0),animation.track_get_key_transition(pelvis_track,key))
	elif needs_split:
		animation.track_insert_key(root_track,0.0,Vector2.ZERO)

func _build_reset(character: Node, pose_root: Node2D, skeleton: Skeleton2D) -> Animation:
	var reset := Animation.new()
	reset.resource_name = "RESET"
	reset.length = 0.1
	_add_reset_node(reset,character,pose_root)
	for bone in skeleton.find_children("*","Bone2D",true,false):
		_add_reset_node(reset,character,bone)
	return reset

func _add_reset_node(reset: Animation, character: Node, node: Node2D) -> void:
	for property in ["position","rotation","scale"]:
		var track := reset.add_track(Animation.TYPE_VALUE)
		reset.track_set_path(track,NodePath("%s:%s" % [character.get_path_to(node),property]))
		reset.track_insert_key(track,0.0,node.get(property))
