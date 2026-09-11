extends SceneTree
var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)

func run() -> void:
	var actor := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
	actor.player_controlled = false
	root.add_child(actor)
	actor.set_physics_process(false)
	var cases := [[&"Idle",0.0],[&"Walk",0.0],[&"Run",0.0],[&"Jump",-160.0],[&"Jump",-1.0],[&"Fall",120.0],[&"Run",0.0],[&"Jump",-120.0]]
	for index in cases.size():
		actor.pose_composer.restore_base()
		actor.action_state = &"None"
		actor.state = cases[index][0]
		actor.velocity = Vector2(80,cases[index][1])
		actor.anim_player.play(actor.state,0)
		actor.anim_player.seek(.17,true)
		var phase_before := actor.anim_player.current_animation_position
		actor.start_attack(1)
		check(actor.anim_player.current_animation_position == phase_before,"Attack must not reset base phase")
		for frame in 64:
			actor.pose_composer.restore_base()
			if frame == 20 and index == 6:
				actor.transition(&"Jump")
				actor.velocity.y = -180
			if frame == 20 and index == 7:
				actor.transition(&"Idle")
				actor.velocity.y = 0
			if actor.is_attacking(): actor.advance_attack(1.0/120.0)
			actor.pose_composer.evaluate(1.0/120.0)
			var result: Dictionary = {}
			for bone in actor.pose_composer.base_pose:
				if "/Thigh" in String(bone.get_path()): result[bone] = bone.global_transform
			var pelvis_position: Vector2 = actor.skeleton.get_node("Pelvis").position
			actor.pose_composer.restore_base()
			check(pelvis_position.is_equal_approx(actor.skeleton.get_node("Pelvis").position),"Action moved pelvis position")
			for bone in result:
				check(bone.global_transform.is_equal_approx(result[bone]),"Action contaminated lower-body transform: "+str(bone.name))
		check(not actor.is_attacking(),"Recovery must release action")
		print("PASS combination ",index,": ",cases[index]," lower body identical to base through attack/recovery")
	actor.rig.character = null
	actor.rig.gait = null
	actor.rig = null
	actor.queue_free()
	await process_frame
	# Real physics comparison: attacking must not alter jump/fall or pause base playback.
	var floor_body := StaticBody2D.new()
	var floor_collision := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(2000,20)
	floor_collision.shape = floor_shape
	floor_body.position = Vector2(0,70)
	floor_body.add_child(floor_collision)
	root.add_child(floor_body)
	var pair: Array[MudCharacter] = []
	for i in 2:
		var a := preload("res://scenes/mud_character.tscn").instantiate() as MudCharacter
		a.player_controlled = false
		a.position = Vector2(i*200,0)
		root.add_child(a)
		pair.append(a)
	for frame in 110:
		for a in pair: a.set_intent(1.0,frame == 35)
		if frame in [30,63]: pair[0].start_attack(1)
		await physics_frame
		check(is_equal_approx(pair[0].velocity.y,pair[1].velocity.y),"Attack changed vertical physics")
		check(pair[0].state == pair[1].state,"Attack replaced movement state")
		check(is_equal_approx(pair[0].anim_player.current_animation_position,pair[1].anim_player.current_animation_position),"Attack paused/reset locomotion playback")
	check(pair[0].is_on_floor(),"Air attack fixture must land")
	for a in pair:
		a.rig.character = null
		a.rig.gait = null
		a.rig = null
		a.queue_free()
	floor_body.queue_free()
	await process_frame
	print("PASS: real Run -> Attack -> Jump and air Attack -> Land match non-attacking control")
	print("LAYERED RESULT: ",errors," failures")
	quit(1 if errors else 0)
