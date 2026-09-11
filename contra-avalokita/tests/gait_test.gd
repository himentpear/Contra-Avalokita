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
		var recovery_bend := 0.0
		var signed_torso_lag := 0.0
		var lag_samples := 0
		var flight_samples := 0
		var longest_flight := 0
		var elbow_min := INF
		var elbow_max := -INF
		for frame in 240:
			rig.gait.weight = 1.0
			rig.gait.run_mix = 0.0 if speed < 50 else 1.0
			rig.pose(1.0 / 120, &"Walk" if speed < 50 else &"Run", Vector2(speed, 0), 0, 0)
			var loaded_leg_bend := INF
			var both_clear := true
			for side in ["Front", "Back"]:
				var cycle := rig.gait.phase + (0.5 if side == "Back" else 0.0)
				var target := rig.gait.foot(cycle)
				var ankle := rig.point("Leg" + side + "End")
				maximum_error = maxf(maximum_error, ankle.distance_to(Vector2(target.x, target.y)))
				maximum_bend = maxf(maximum_bend, rig.angles["Leg" + side])
				if rig.gait.contact_phase(cycle) < rig.gait.stance:
					loaded_leg_bend = minf(loaded_leg_bend, rig.angles["Leg" + side])
					var support_progress := rig.gait.contact_phase(cycle) / rig.gait.stance
					if support_progress > 0.70 and support_progress < 0.85:
						recovery_bend = maxf(recovery_bend, rig.angles["Leg" + side])
				var flatten := rig.gait.foot_flatten(cycle)
				var toe_radius := maxf(1.8, 3.0 - flatten - 0.35)
				maximum_penetration = maxf(maximum_penetration, rig.point("Leg" + side + "Toe").y + toe_radius - 3.0)
				var pitch: float = rig.anchors["Leg" + side + "End"].rotation
				var heel := ankle - Vector2.RIGHT.rotated(pitch)
				var sole := maxf(heel.y, rig.point("Leg" + side + "Toe").y - 0.2)
				both_clear = both_clear and sole < -2.0
			flight_samples = flight_samples + 1 if both_clear else 0
			longest_flight = maxi(longest_flight, flight_samples)
			elbow_min = minf(elbow_min, rig.angles["ArmFront"])
			elbow_max = maxf(elbow_max, rig.angles["ArmFront"])
			if not is_inf(loaded_leg_bend): maximum_support_bend = maxf(maximum_support_bend, loaded_leg_bend)
			chest_min = minf(chest_min, rig.point(&"Chest").y)
			chest_max = maxf(chest_max, rig.point(&"Chest").y)
			var shoulder_offset := rig.point(&"ShoulderFront").y - rig.point(&"Chest").y
			shoulder_min = minf(shoulder_min, shoulder_offset)
			shoulder_max = maxf(shoulder_max, shoulder_offset)
			if frame > 60:
				var lean_angle := deg_to_rad(lerpf(rig.gait.walk_torso_lean_degrees, rig.gait.run_torso_lean_degrees, rig.gait.run_mix))
				var desired_chest_x := rig.point(&"Pelvis").x + sin(lean_angle) * rig.torso_length
				maximum_torso_lag = maxf(maximum_torso_lag, desired_chest_x - rig.point(&"Chest").x)
				signed_torso_lag += desired_chest_x - rig.point(&"Chest").x
				lag_samples += 1
		check(maximum_error < 0.05, "%.0f speed: feet follow trajectories without unreachable IK (error %.3f)" % [speed, maximum_error])
		check(maximum_bend < 140, "%.0f speed: knees remain inside folding limit" % speed)
		# Down intentionally bends the loaded knee; it must straighten again for drive.
		check(recovery_bend < 38, "%.0f speed: support leg re-extends after accepting weight (%.1f deg)" % [speed, recovery_bend])
		check(maximum_support_bend < 70, "%.0f speed: acceptance compression is bounded (%.1f deg)" % [speed, maximum_support_bend])
		check(absf(signed_torso_lag / lag_samples) < 0.6 and maximum_torso_lag < 2.5, "%.0f speed: mass lag rebounds rather than retaining backward bias" % speed)
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
			var down_phase := rig.gait.stance * rig.gait.acceptance_peak
			var drop := rig.gait.support_height(0, 0, 32, 0) - rig.gait.support_height(0, 0, 32, down_phase)
			check(drop >= 1.5, "Walk: visible contact-to-down drop (%.2f logical / %.2f display px)" % [drop, drop * 2])
			check(rig.gait.foot(0.75).y < -6, "Walk: passing foot has deliberate clearance")
			check(longest_flight == 0, "Walk: no unintentional flight interval")
			rig.gait.phase = rig.gait.stance * rig.gait.acceptance_peak
			rig.pose(0, &"Walk", Vector2(speed, 0), 0, 0)
			var down_bend: float = rig.angles["LegFront"]
			rig.gait.phase = rig.gait.stance * 0.52
			rig.pose(0, &"Walk", Vector2(speed, 0), 0, 0)
			var passing_bend: float = rig.angles["LegFront"]
			check(passing_bend <= down_bend - 5.0, "Walk: support knee straightens from Down to Passing (%.1f -> %.1f deg)" % [down_bend, passing_bend])
			check(rig.gait.foot_flatten(rig.gait.stance * 0.22) > 0.9, "Walk: sole visibly flattens under accepted weight")
			check(rig.gait.foot(0).z < -0.1 and rig.gait.foot(rig.gait.stance * 0.5).z > -0.02 and rig.gait.foot(rig.gait.stance * 0.9).z > 0.05, "Walk: foot rolls heel -> full sole -> toe")
		else:
			check(rig.gait.support_height(0, 0, 32, 0.1) > rig.gait.support_height(0, 0, 32, 0.2) + 0.5, "Reference run: suspended pelvis is above contact pelvis")
			check(longest_flight / 120.0 >= 0.075, "Run: both soles visibly airborne for %.3f seconds" % (longest_flight / 120.0))
			check(absf(rig.gait.foot(0.2).x) < 8, "Run: landing stays near pelvis instead of overstriding")
			check(elbow_min >= 69.9 and elbow_max <= 110.1, "Run: elbows remain bent while pumping (%.1f..%.1f deg)" % [elbow_min, elbow_max])
			var minimum_flight_lean := INF
			for sample_index in 120:
				rig.gait.phase = sample_index / 120.0
				rig.pose(0, &"Run", Vector2(speed, 0), 0, 0)
				if rig.gait.phase_label() == "Flight": minimum_flight_lean = minf(minimum_flight_lean, rig.point(&"Chest").x - rig.point(&"Pelvis").x)
			check(minimum_flight_lean >= sin(deg_to_rad(5.0)) * rig.torso_length, "Run: chest remains at least 5 degrees ahead during flight")
			# Swapping phase by half a cycle swaps legs without changing their local solution.
			rig.gait.phase = 0.17
			rig.pose(0, &"Run", Vector2(speed, 0), 0, 0)
			var front_relative := rig.point(&"LegFrontJoint") - rig.point(&"Pelvis")
			rig.gait.phase = 0.67
			rig.pose(0, &"Run", Vector2(speed, 0), 0, 0)
			var back_relative := rig.point(&"LegBackJoint") - rig.point(&"Pelvis")
			check(front_relative.distance_to(back_relative) < 0.01, "Run: left/right leg solutions are exact half-cycle mirrors")
	var event_gait := MudLocomotion.new()
	var events: Array[StringName] = []
	event_gait.foot_contact.connect(func(side: StringName) -> void: events.append(side))
	for frame in 180: event_gait.advance(1.0 / 60.0, 105.0, true, 32.0)
	var alternating := events.size() >= 8
	for i in range(1, events.size()): alternating = alternating and events[i] != events[i - 1]
	check(alternating, "Contact is a phase-crossing event and alternates feet (%d events)" % events.size())
	rig.gait.phase = 0.3
	for frame in 12: rig.pose(1.0 / 60.0, &"Run", Vector2(105, 0), 0, 0)
	var pelvis_before := rig.point(&"Pelvis")
	rig.pose(1.0 / 60, &"Idle", Vector2.ZERO, 0, 0)
	var stop_delta := pelvis_before.distance_to(rig.point(&"Pelvis"))
	check(stop_delta < 2, "Stopping blends body pose instead of snapping (%.2f px)" % stop_delta)
	print("GAIT RESULT: %d failures" % failures)
	quit(1 if failures else 0)
