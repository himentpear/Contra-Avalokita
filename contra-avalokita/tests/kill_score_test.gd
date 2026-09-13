extends SceneTree
const Profile = preload("res://scripts/enemy_score_profile.gd")
const Event = preload("res://gameplay/combat/hit/hit_event.gd")
const ScoreSystem = preload("res://gameplay/roguelike/scoring/score_system.gd")
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var score := ScoreSystem.new()
	score.name = "ScoreSystem"
	root.add_child(score)
	var profile = Profile.new()
	profile.base_score = 400
	score.reset_run()
	score.streak = 7
	score.last_kill = score.clock
	var result: Dictionary = score.settle("example",profile,1.4,1.6,1.4,{"perfect_parry":true,"execution":true,"air_kill":true})
	assert(result.points == 1656)
	assert(score.settle("example",profile,1,1,1,{}).is_empty())
	assert(score.total == 1656)
	score.reset_run()
	profile.base_score = 100
	for i in 7:
		result = score.settle(str(i),profile,1,1,1,{})
		assert(result.penalty == [0,0,20,40,60,80,80][i])
	score.streak=100
	assert(is_equal_approx(score.settle("cap",profile,1,1,1,{}).combo,1.8))
	var arena = load("res://scenes/test_arena.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	score.reset_run()
	arena.spawn_score_target()
	var enemy = arena.scoring_enemy
	var player = arena.player
	var hit = Event.new()
	hit.attacker = player
	hit.attack_name = &"Blade/Attack_1"
	hit.attack_token = 1
	hit.damage = 100
	enemy.receive_hit(hit)
	assert(enemy.state == &"Dead")
	assert(score.total > 0 and score.streak == 1)
	var before: int = score.total
	enemy.receive_hit(hit)
	assert(score.total == before)
	enemy.revive()
	enemy.receive_hit(hit)
	assert(score.total > before and score.streak == 2)
	score.streak=9
	score.note_heavy_hit(player)
	assert(score.streak == 4)
	score.clock += score.combo_timeout+1
	score._process(0)
	assert(score.streak == 0)
	score.realm=1
	assert(score.resonance({"perfect_parry":true,"heavy":true}) == 1.4)
	assert(score.resonance({"safe_ranged":true}) == .8)
	# Taking damage before the player's first strike must invalidate no-damage.
	score.reset_run()
	enemy.revive()
	var incoming = Event.new()
	incoming.attacker = enemy
	incoming.damage = 1
	player.receive_hit(incoming)
	enemy.receive_hit(hit)
	assert(not score.last_result.tags.has("no_damage"))
	# Test consecutive kill push transition and increased duration (5.0s dwell window)
	score.reset_run()
	var hud: Node2D = score.hud
	assert(hud != null)
	assert(hud.result_duration == 5.0)
	assert(hud.result_fade_start == 4.25)
	
	score.settle("kill_1", profile, 1.0, 1.0, 1.0, {"perfect_parry": true})
	hud.update_kill_result(score.last_result)
	assert(hud.displayed_result.points > 0)
	assert(hud.prev_result.is_empty())
	
	# Advance time by 2.0s (within 5.0s window) and trigger kill 2
	score.clock += 2.0
	score.settle("kill_2", profile, 1.2, 1.1, 1.0, {"perfect_parry": true, "weakpoint": true})
	hud.update_kill_result(score.last_result)
	assert(not hud.prev_result.is_empty())
	assert(hud.prev_result.points != hud.displayed_result.points)
	assert(hud.transition_clock == score.clock)
	var is_pushing: bool = not hud.prev_result.is_empty() and (score.clock - hud.transition_clock) <= hud.push_transition_duration
	assert(is_pushing)
	
	# Verify row replacement differentiation: identical tag does not push, new tag pushes
	var old_tags = hud.get_visible_tags(hud.prev_result)
	var new_tags = hud.get_visible_tags(hud.displayed_result)
	assert(old_tags.size() == 1 and new_tags.size() == 2)
	assert(old_tags[0] == new_tags[0]) # "完美格挡" matches -> stays stationary
	assert(new_tags[1] == "弱点打击") # New tag -> pushed in

	# Advance clock past push transition duration
	score.clock += hud.push_transition_duration + 0.1
	is_pushing = not hud.prev_result.is_empty() and (score.clock - hud.transition_clock) <= hud.push_transition_duration
	assert(not is_pushing)

	score.reset_run()
	profile.base_score=400
	score.streak=7
	score.last_kill=score.clock
	score.settle("preview",profile,1.4,1.6,1.4,{"perfect_parry":true,"execution":true,"air_kill":true})
	if "--preview" in OS.get_cmdline_user_args() or "--preview" in OS.get_cmdline_args():
		for i in 80: await physics_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/kill_score_preview.png")
	print("PASS: formula 1656, repeat penalties, streak cap/decay/timeout, real death, duplicate protection, revive, resonance, 5s dwell & push transitions")
	for character in [arena.player, arena.scoring_enemy]+arena.crowd:
		for connection in character.rig.gait.foot_contact.get_connections():
			character.rig.gait.foot_contact.disconnect(connection.callable)
		character.rig.character = null
	arena.queue_free()
	await process_frame
	await process_frame
	quit()
