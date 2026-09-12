extends SceneTree
## One-time authoring helper: samples the current procedural wall poses into an
## external AnimationLibrary that remains editable in Godot's Animation panel.

const OUTPUT := "res://resources/wall_animation_library.tres"
const TRACKS := [
	{"path": "Visual/Skeleton2D/Pelvis:position", "node": "Visual/Skeleton2D/Pelvis", "property": "position"},
	{"path": "Visual/Skeleton2D/Pelvis:rotation", "node": "Visual/Skeleton2D/Pelvis", "property": "rotation"},
	{"path": "Visual/Skeleton2D/Pelvis/Torso:position", "node": "Visual/Skeleton2D/Pelvis/Torso", "property": "position"},
	{"path": "Visual/Skeleton2D/Pelvis/Torso:rotation", "node": "Visual/Skeleton2D/Pelvis/Torso", "property": "rotation"},
	{"path": "Visual/Skeleton2D/Pelvis/Torso/Head:rotation", "node": "Visual/Skeleton2D/Pelvis/Torso/Head", "property": "rotation"},
	{"path": "Visual/Skeleton2D/Pelvis/Torso/UpperArmFront:position", "node": "Visual/Skeleton2D/Pelvis/Torso/UpperArmFront", "property": "position"},
	{"path": "Visual/Skeleton2D/Pelvis/Torso/UpperArmFront:rotation", "node": "Visual/Skeleton2D/Pelvis/Torso/UpperArmFront", "property": "rotation"},
	{"path": "Visual/Skeleton2D/Pelvis/Torso/UpperArmFront/ForearmFront:rotation", "node": "Visual/Skeleton2D/Pelvis/Torso/UpperArmFront/ForearmFront", "property": "rotation"},
	{"path": "Visual/Skeleton2D/Pelvis/Torso/UpperArmBack:rotation", "node": "Visual/Skeleton2D/Pelvis/Torso/UpperArmBack", "property": "rotation"},
	{"path": "Visual/Skeleton2D/Pelvis/Torso/UpperArmBack/ForearmBack:rotation", "node": "Visual/Skeleton2D/Pelvis/Torso/UpperArmBack/ForearmBack", "property": "rotation"},
	{"path": "Visual/Skeleton2D/Pelvis/ThighFront:rotation", "node": "Visual/Skeleton2D/Pelvis/ThighFront", "property": "rotation"},
	{"path": "Visual/Skeleton2D/Pelvis/ThighFront/ShinFront:rotation", "node": "Visual/Skeleton2D/Pelvis/ThighFront/ShinFront", "property": "rotation"},
	{"path": "Visual/Skeleton2D/Pelvis/ThighFront/ShinFront/FootFront:rotation", "node": "Visual/Skeleton2D/Pelvis/ThighFront/ShinFront/FootFront", "property": "rotation"},
	{"path": "Visual/Skeleton2D/Pelvis/ThighBack:rotation", "node": "Visual/Skeleton2D/Pelvis/ThighBack", "property": "rotation"},
	{"path": "Visual/Skeleton2D/Pelvis/ThighBack/ShinBack:rotation", "node": "Visual/Skeleton2D/Pelvis/ThighBack/ShinBack", "property": "rotation"},
	{"path": "Visual/Skeleton2D/Pelvis/ThighBack/ShinBack/FootBack:rotation", "node": "Visual/Skeleton2D/Pelvis/ThighBack/ShinBack/FootBack", "property": "rotation"},
]

const CLIPS := [
	{"name": "Hang", "action": &"WallHang", "length": 0.18, "times": [0.0, 0.07, 0.18], "base": &"Air/Fall"},
	{"name": "Slide", "action": &"WallSlide", "length": 0.18, "times": [0.0, 0.045, 0.09, 0.135, 0.18], "base": &"Air/Fall", "loop": true},
	{"name": "Push", "action": &"WallPush", "length": 0.075, "times": [0.0, 0.025, 0.05, 0.075], "base": &"Air/JumpSquat"},
	{"name": "Release", "action": &"WallRelease", "length": 0.14, "times": [0.0, 0.035, 0.07, 0.105, 0.14], "base": &"Air/Takeoff"},
]

func _initialize() -> void:
	call_deferred("generate")

func generate() -> void:
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	root.add_child(actor)
	await process_frame
	actor.set_physics_process(false)
	actor.weapons.equip(null)
	actor.state = &"Fall"
	actor.facing = 1.0
	actor.visual.scale = Vector2.ONE
	actor.wall_side = 1.0
	actor.wall_surface_x = 12.0
	actor.wall_hand_anchor_y = -51.0
	actor.wall_foot_anchor_y = -22.0

	var library := AnimationLibrary.new()
	for definition in CLIPS:
		var animation := Animation.new()
		animation.resource_name = definition.name
		animation.length = definition.length
		animation.loop_mode = Animation.LOOP_LINEAR if definition.get("loop", false) else Animation.LOOP_NONE
		for track_definition in TRACKS:
			var track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track, NodePath(track_definition.path))
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)

		actor.pose_composer.wall_composer.reset()
		var prev_time := 0.0
		for key_time in definition.times:
			actor.pose_composer.restore_base()
			actor.anim_player.play(definition.base, 0.0)
			actor.anim_player.seek(minf(key_time, actor.anim_player.current_animation_length), true)
			actor.anim_player.advance(0.0)
			actor.wall_action = definition.action
			actor.wall_action_time = key_time
			actor.wall_slide_scrape_offset = sin(key_time * 21.0) if definition.action == &"WallSlide" else 0.0
			var step_delta: float = key_time - prev_time if key_time > prev_time else 0.016
			actor.pose_composer.evaluate(step_delta)
			prev_time = key_time
			for track_index in TRACKS.size():
				var track_definition: Dictionary = TRACKS[track_index]
				var bone := actor.get_node(NodePath(track_definition.node))
				animation.track_insert_key(track_index, key_time, bone.get(track_definition.property))

		library.add_animation(StringName(definition.name), animation)

	DirAccess.make_dir_recursive_absolute("res://resources")
	var result := ResourceSaver.save(library, OUTPUT)
	if result != OK:
		push_error("Failed to save wall animation library: %s" % error_string(result))
		quit(1)
		return
	print("Generated ", OUTPUT, " with Hang, Slide, Push and Release")
	quit()
