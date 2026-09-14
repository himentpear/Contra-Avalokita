extends SceneTree

const TEST_SCENE := "res://tests/rotobone_mud_character_test.tscn"
const REFERENCE := "res://assets/2D-Pixel-Art-Character-Template/2D-Pixel-Art-Character-Template/Sword Attack/player sword atk 64x64.png"


func _initialize() -> void:
	var player_input := root.get_node_or_null("PlayerInput")
	if player_input:
		player_input.process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("_render_frames")


func _render_frames() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(920, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := (load(TEST_SCENE) as PackedScene).instantiate()
	viewport.add_child(scene)
	var overlay := scene.get_node("ReferenceOverlay") as RotoBoneViewportOverlay
	overlay.reference_texture = load(REFERENCE)
	overlay.hframes = 6
	overlay.vframes = 1
	overlay.pivot_px = Vector2(32, 48)
	overlay.opacity = 0.24
	var player := scene.get_node("AnimationPlayer") as AnimationPlayer
	var mud := scene.get_node("MudCharacterInstance")
	mud.get_node("Visual/WeaponSlots").visible = false
	var renderer := mud.get_node("Visual/MudBodyRenderer") as MudBodyRenderer
	var skeleton := mud.get_node("Visual/PoseRoot/Skeleton2D") as Skeleton2D
	for frame_index in 6:
		overlay.frame = frame_index
		player.play(&"AssetActions/Sword Attack")
		player.seek(frame_index / 12.0, true)
		player.pause()
		renderer.sync_skeleton(skeleton)
		await process_frame
		await process_frame
		var image := viewport.get_texture().get_image()
		var output := "res://.godot/rotobone_sword_attack_f%02d.png" % (frame_index + 1)
		image.save_png(ProjectSettings.globalize_path(output))
		print(output)
	root.remove_child(viewport)
	viewport.free()
	quit(0)
