extends SceneTree
## GPU preview for the unmodified body and five roguelike SDF morph profiles.

const SAMPLES := [
	{"label": "BASE", "profile": ""},
	{"label": "SWOLLEN ARM", "profile": "res://content/base/morphs/swollen_arm.tres"},
	{"label": "HUNGRY GHOST", "profile": "res://content/base/morphs/hungry_ghost.tres"},
	{"label": "ASURA SHOULDER", "profile": "res://content/base/morphs/asura_shoulder.tres"},
	{"label": "HOLLOW FACE", "profile": "res://content/base/morphs/hollow_face.tres"},
	{"label": "SPINE GROWTH", "profile": "res://content/base/morphs/spine_growth.tres"},
]

func _initialize() -> void:
	call_deferred("capture")

func make_label(parent: Node, text: String, position: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = Vector2(190.0, 20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color("cbd9a7")
	parent.add_child(label)

func capture() -> void:
	var debug_last_sample := OS.get_cmdline_user_args().has("--debug-modifiers")
	root.size = Vector2i(720, 360)
	var stage := Node2D.new()
	root.add_child(stage)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(720.0, 360.0)
	backdrop.color = Color("101d24")
	stage.add_child(backdrop)
	var title := Label.new()
	title.text = "ROGUELIKE SDF BODY MORPHS"
	title.position = Vector2(225.0, 336.0)
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color("e4cf79")
	stage.add_child(title)

	for i in SAMPLES.size():
		var column := i % 3
		var row := i / 3
		var center := Vector2(120.0 + column * 240.0, 120.0 + row * 165.0)
		var holder := Node2D.new()
		holder.position = center
		holder.scale = Vector2(1.25, 1.25)
		stage.add_child(holder)
		var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		actor.player_controlled = false
		holder.add_child(actor)
		actor.set_physics_process(false)
		actor.weapons.equip(null)
		actor.anim_player.play(&"Punch/Attack_1", 0.0)
		actor.anim_player.seek(0.14, true)
		actor.anim_player.advance(0.0)
		if SAMPLES[i].profile != "":
			actor.body_renderer.apply_morph_profile(load(SAMPLES[i].profile))
		if debug_last_sample and i == SAMPLES.size() - 1:
			actor.body_renderer.modifier_debug_draw = true
		actor.body_renderer.sync_skeleton(actor.skeleton)
		make_label(stage, SAMPLES[i].label, Vector2(center.x - 95.0, center.y + 26.0))

	await process_frame
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var image := root.get_texture().get_image()
	if not image:
		push_error("A real rendering driver is required for sdf_morph_preview.gd")
		quit(1)
		return
	image.save_png("res://artifacts/sdf_morph_preview.png")
	print("Captured artifacts/sdf_morph_preview.png")
	quit()
