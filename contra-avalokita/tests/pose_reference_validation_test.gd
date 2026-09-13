extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var character := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	var skeleton := character.get_node("Visual/PoseRoot/Skeleton2D") as Skeleton2D
	var pose_root := character.get_node("Visual/PoseRoot") as Node2D
	var player := character.get_node("AnimationPlayer") as AnimationPlayer
	var validator := character.get_node("PoseValidation") as MudPoseReferenceValidator
	assert(skeleton != null and pose_root != null and validator != null)
	assert(validator.validate_reference_pose(false).is_empty())
	var reset := player.get_animation(&"RESET")
	var bones := skeleton.find_children("*","Bone2D",true,false)
	assert(reset.get_track_count() == 3+bones.size()*3)
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		for animation_name in library.get_animation_list():
			var animation := library.get_animation(animation_name)
			for track in animation.get_track_count():
				var path_text := String(animation.track_get_path(track))
				assert(not path_text.begins_with("Visual/Skeleton2D"))
				var target_path := NodePath(path_text.get_slice(":",0))
				assert(character.get_node_or_null(target_path) != null,"Broken animation path: %s/%s -> %s" % [library_name,animation_name,path_text])
			if animation_name != &"RESET":
				var root_track := animation.find_track(NodePath("Visual/PoseRoot:position"),Animation.TYPE_VALUE)
				assert(root_track >= 0,"Animation does not reset/author PoseRoot: %s/%s" % [library_name,animation_name])
				var pelvis_track := animation.find_track(NodePath("Visual/PoseRoot/Skeleton2D/Pelvis:position"),Animation.TYPE_VALUE)
				if pelvis_track >= 0:
					for key in animation.track_get_key_count(pelvis_track):
						assert(is_zero_approx((animation.track_get_key_value(pelvis_track,key) as Vector2).x),"Pelvis owns root X in %s/%s" % [library_name,animation_name])
	# Prove the guard reports pollution and clears once restored.
	var pelvis := skeleton.get_node("Pelvis") as Bone2D
	pelvis.position.x += 2.0
	var failures := validator.validate_reference_pose(false)
	assert(failures.any(func(message: String) -> bool: return "Pelvis.position" in message))
	pelvis.transform = pelvis.rest
	assert(validator.validate_reference_pose(false).is_empty())
	print("PASS: canonical Bone2D rest, complete RESET, PoseRoot ownership, valid animation paths, drift reporting")
	character.free()
	quit()
