extends SceneTree
const Glyphs = preload("res://scripts/six_realm_glyphs.gd")

class Sheet extends Node2D:
	func _draw() -> void:
		for i in 6:
			draw_set_transform(Vector2(70+i*100,108),0,Vector2.ONE*2)
			Glyphs.draw_symbol(self,i,Color("edf5f3"),.7)
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(Glyphs.digits(0) == [0])
	assert(Glyphs.digits(5) == [5])
	assert(Glyphs.digits(6) == [1,0])
	assert(Glyphs.digits(10) == [1,4])
	assert(Glyphs.digits(36) == [1,0,0])
	assert(Glyphs.number_tokens(1.5) == [1,-1,3])
	assert(Glyphs.number_tokens(5.999) == [1,0])
	var sheet := Sheet.new()
	root.add_child(sheet)
	for i in 6:
		var label := Label.new()
		label.text = "%d / %s" % [i,Glyphs.NAMES[i]]
		label.position = Vector2(30+i*100,164)
		label.add_theme_font_size_override("font_size",12)
		root.add_child(label)
	var title := Label.new()
	title.text = "SIX REALMS / BASE SIX\nWHITE-LINE COMBAT NUMERALS"
	title.position = Vector2(24,20)
	root.add_child(title)
	var feedback := preload("res://gameplay/combat/hit/realm_hit_feedback.gd").new()
	root.add_child(feedback)
	feedback.add_number(Vector2(180,255),10)
	feedback.add_number(Vector2(440,255),36)
	feedback.set_process(false)
	var note := Label.new()
	note.text = "DECIMAL 10 = BASE SIX 14                       DECIMAL 36 = BASE SIX 100"
	note.position = Vector2(55,290)
	note.add_theme_font_size_override("font_size",12)
	root.add_child(note)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/six_realms_symbols.png")
	for i in 30: feedback.add_number(Vector2.ZERO,i)
	assert(feedback.popups.size() == feedback.max_popups)
	feedback._process(2.0)
	assert(feedback.popups.is_empty())
	var dummy := preload("res://scripts/training_dummy.gd").new()
	root.add_child(dummy)
	dummy.receive_hit(10.0)
	var live := root.get_node("RealmHitFeedback")
	assert(live.popups.back().digits == [1,4],"Actual hit must emit the base-six amount")
	print("PASS: base-six integers, fractional damage, rounding carry, popup bound and expiry")
	quit()
