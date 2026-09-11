extends SceneTree
var failures := 0

func check(condition: bool, description: String) -> void:
	if condition: print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rig := MudRig.new()
	root.add_child(rig)
	for speed in [45.0, 105.0]:
		var maximum_error := 0.0
		var maximum_bend := 0.0
		var maximum_penetration := 0.0
		var chest_min := INF
		var chest_max := -INF
		var shoulder_min := INF
		var shoulder_max := -INF
		var maximum_support_bend := 0.0
		var maximum_torso_lag := 0.0
		for frame in 240:
			rig.gait.weight = 1.0
			rig.gait.run_mix = 0.0 if speed < 50 else 1.0
			rig.pose(1.0 / 120, &"Walk" if speed < 50 else &"Run", Vector2(speed, 0), 0, 0)
			var loaded_leg_bend := INF
			for side in ["Front", "Back"]:
				var cycle := rig.gait.phase + (0.5 if side == "Back" else 0.0)
				var target := rig.gait.foot(cycle)
				var ankle := rig.point("Leg" + side + "End")
				maximum_error = maxf(maximum_error, ankle.distance_to(Vector2(target.x, target.y)))
				maximum_bend = maxf(maximum_bend, rig.angles["Leg" + side])
				if rig.gait.contact_phase(cycle) < rig.gait.stance:
					loaded_leg_bend = minf(loaded_leg_bend, rig.angles["Leg" + side])
				maximum_penetration = maxf(maximum_penetration, rig.point("Leg" + side + "Toe").y)
			if not is_inf(loaded_leg_bend): maximum_support_bend = maxf(maximum_support_bend, loaded_leg_bend)
			chest_min = minf(chest_min, rig.point(&"Chest").y)
			chest_max = maxf(chest_max, rig.point(&"Chest").y)
			var shoulder_offset := rig.point(&"ShoulderFront").y - rig.point(&"Chest").y
			shoulder_min = minf(shoulder_min, shoulder_offset)
			shoulder_max = maxf(shoulder_max, shoulder_offset)
			if frame > 60:
				var desired_chest_x := rig.point(&"Pelvis").x + 1.5 + lerpf(rig.gait.walk_lean, rig.gait.run_lean, rig.gait.run_mix)
				maximum_torso_lag = maxf(maximum_torso_lag, desired_chest_x - rig.point(&"Chest").x)
		check(maximum_error < 0.05, "%.0f speed: feet follow trajectories without unreachable IK (error %.3f)" % [speed, maximum_error])
		check(maximum_bend < 140, "%.0f speed: knees remain inside folding limit" % speed)
		check(maximum_support_bend < (28.0 if speed < 50 else 42.0), "%.0f speed: support leg is extended, not crouched (max %.1f deg)" % [speed, maximum_support_bend])
		check(maximum_torso_lag < 0.6, "%.0f speed: no sustained backward torso drag (%.2f px)" % [speed, maximum_torso_lag])
		check(maximum_penetration < 0.01, "%.0f speed: toe never penetrates support plane" % speed)
		check(chest_max - chest_min > 0.5 and shoulder_max - shoulder_min > 1, "%.0f speed: torso and shoulders participate in weight transfer" % speed)
		var phase_offset := 0.2 * rig.gait.run_mix
		var a := rig.gait.foot(phase_offset + rig.gait.stance * 0.35)
		var b := rig.gait.foot(phase_offset + rig.gait.stance * 0.35 + rig.gait.cycles_per_second / 120.0)
		check(absf(b.x - a.x + speed / 120.0) < 0.001, "%.0f speed: planted foot cancels world travel" % speed)
		for boundary in [phase_offset, phase_offset + rig.gait.stance]:
			var before := rig.gait.foot(boundary - 0.00001)
			var after := rig.gait.foot(boundary + 0.00001)
			check(before.distance_to(after) < 0.01, "%.0f speed: contact/swing transition is continuous" % speed)
			var height_before := rig.gait.support_height(0, 0, 32, boundary - 0.00001)
			var height_after := rig.gait.support_height(0, 0, 32, boundary + 0.00001)
			check(absf(height_after - height_before) < 0.12, "%.0f speed: pelvis remains continuous at contact/toe-off (%.3f px)" % [speed, absf(height_after - height_before)])
		if speed < 50:
			check(rig.gait.support_height(0, 0, 32, 0.25) > rig.gait.support_height(0, 0, 32, 0.0) + 0.5, "Reference walk: passing pelvis is above stride pelvis")
		else:
			check(rig.gait.support_height(0, 0, 32, 0.1) > rig.gait.support_height(0, 0, 32, 0.2) + 0.5, "Reference run: suspended pelvis is above contact pelvis")
	var pelvis_before := rig.point(&"Pelvis")
	rig.pose(1.0 / 60, &"Idle", Vector2.ZERO, 0, 0)
	check(pelvis_before.distance_to(rig.point(&"Pelvis")) < 2, "Stopping blends body pose instead of snapping")
	print("GAIT RESULT: %d failures" % failures)
	quit(1 if failures else 0)
