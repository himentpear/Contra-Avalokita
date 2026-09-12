class_name MudPoseComposer
extends Node2D
## Base animation is evaluated first. Only explicitly owned bones receive action poses.
@export var idle_pelvis_limit := 0.14
@export var moving_pelvis_limit := 0.06
@export var air_pelvis_limit := 0.035
@export var attack_blend_in := 0.055
@export_range(0.4,0.95) var recovery_start := 0.68
var character: MudCharacter
var base_pose: Dictionary = {}
var weight := 0.0
var block_weight := 0.0
@export var blade_footwork: Resource = preload("res://scripts/mud_blade_footwork.gd").new()
var lower_body_weight := 0.0
var footwork_lead := "Front"
var last_action_time := -1.0
var last_action_stage := -1
const WALL_ANIMATION_REFERENCE_PLANE_X := 12.0

func restore_base() -> void:
	for bone in base_pose:
		if is_instance_valid(bone): bone.transform = base_pose[bone]

func evaluate(delta: float) -> void:
	var player := character.anim_player
	if character.state in [&"Jump", &"Fall"] and not String(player.current_animation).begins_with("Air/"):
		var vertical := character.velocity.y
		var progress := 1.0-clampf(-vertical/absf(character.jump_velocity),0,1) if vertical < 0 else clampf(vertical/absf(character.jump_velocity),0,1)
		player.seek(progress*player.current_animation_length,true)
		player.advance(0.0)
	else:
		player.advance(delta)
	base_pose.clear()
	for bone in character.skeleton.find_children("*","Bone2D"):
		base_pose[bone] = bone.transform
	weight = 0.0
	lower_body_weight = 0.0
	character.weapons.blade_projection = 1.0
	character.weapons.blade_depth = 0.0

	if character.is_blocking():
		block_weight = minf(1.0, block_weight + delta / 0.06)
	else:
		block_weight = maxf(0.0, block_weight - delta / 0.06)

	if character.is_attacking():
		apply_action()
	elif block_weight > 0.001:
		apply_block(block_weight)
	if character.wall_action != &"None":
		apply_wall_action()

	if character.has_reaction():
		apply_reaction(delta)
	queue_redraw()

func _solve_wall_chain(upper: Bone2D, lower: Bone2D, end: Bone2D, target_global: Vector2, bend_sign: float, weight: float) -> void:
	if not is_instance_valid(upper) or not is_instance_valid(lower) or not is_instance_valid(end):
		return
	var parent := upper.get_parent() as Node2D
	if not parent:
		return
	var root := upper.position
	var target := parent.to_local(target_global)
	var delta := target - root
	var upper_length := lower.position.length()
	var lower_length := end.position.length()
	if delta.length_squared() < 0.001 or upper_length < 0.01 or lower_length < 0.01:
		return
	var distance := clampf(delta.length(), absf(upper_length - lower_length) + 0.15, upper_length + lower_length - 0.15)
	var solved_target := root + delta.normalized() * distance
	var shoulder_cos := clampf((upper_length * upper_length + distance * distance - lower_length * lower_length) / (2.0 * upper_length * distance), -1.0, 1.0)
	var bend := bend_sign
	if is_zero_approx(bend):
		# Treat the keyed AnimationPlayer pose as the pole/hint. This keeps the
		# contact target procedural while letting artists flip or reshape the knee
		# directly in the animation editor.
		var target_angle := (solved_target - root).angle()
		var bend_angle := acos(shoulder_cos)
		var plus_upper := target_angle + bend_angle - PI * 0.5
		var minus_upper := target_angle - bend_angle - PI * 0.5
		var authored_knee := parent.to_local(lower.global_position)
		var plus_knee := root + Vector2(0.0, upper_length).rotated(plus_upper)
		var minus_knee := root + Vector2(0.0, upper_length).rotated(minus_upper)
		bend = 1.0 if authored_knee.distance_squared_to(plus_knee) <= authored_knee.distance_squared_to(minus_knee) else -1.0
	var solved_upper := (solved_target - root).angle() + bend * acos(shoulder_cos) - PI * 0.5
	upper.rotation = lerp_angle(upper.rotation, solved_upper, weight)
	var solved_target_global := parent.to_global(solved_target)
	var target_in_upper := upper.to_local(solved_target_global)
	var solved_lower := (target_in_upper - lower.position).angle() - PI * 0.5
	lower.rotation = lerp_angle(lower.rotation, solved_lower, weight)

func _point_foot_at_wall(foot: Bone2D, weight: float) -> void:
	if not is_instance_valid(foot) or not foot.get_parent() is Node2D:
		return
	var parent := foot.get_parent() as Node2D
	var direction_point := foot.global_position + Vector2(character.wall_side, 0.0)
	var local_direction := parent.to_local(direction_point) - foot.position
	foot.rotation = lerp_angle(foot.rotation, local_direction.angle(), weight)

func apply_wall_action() -> void:
	var pelvis := character.skeleton.get_node_or_null("Pelvis") as Bone2D
	var torso := character.skeleton.get_node_or_null("Pelvis/Torso") as Bone2D
	var head := character.skeleton.get_node_or_null("Pelvis/Torso/Head") as Bone2D
	var upper_f := character._upper_arm_front_bone
	var fore_f := character._forearm_front_bone
	var hand_f := character._hand_front_bone
	var upper_b := character._upper_arm_back_bone
	var fore_b := character._forearm_back_bone
	var hand_b := character._hand_back_bone
	var thigh_f := character._thigh_front_bone
	var shin_f := character._shin_front_bone
	var foot_f := character._foot_front_bone
	var thigh_b := character._thigh_back_bone
	var shin_b := character._shin_back_bone
	var foot_b := character._foot_back_bone
	if not pelvis or not torso or character.wall_side == 0.0:
		return

	var action := character.wall_action
	var wall_x := character.wall_surface_x
	if is_inf(wall_x):
		wall_x = character.global_position.x + character.wall_side * 10.0
	var hang_weight := smoothstep(0.0, 0.07, character.wall_action_time) if action == &"WallHang" else 1.0
	var main_hand_target := Vector2(wall_x - character.wall_side * 1.5, character.wall_hand_anchor_y + character.wall_slide_scrape_offset)
	var assist_hand_target := Vector2(wall_x - character.wall_side * 2.5, character.wall_hand_anchor_y + 9.0 + character.wall_slide_scrape_offset * 0.5)
	var high_foot_target := Vector2(wall_x - character.wall_side * 3.5, character.wall_foot_anchor_y + character.wall_slide_scrape_offset)
	var low_foot_target := Vector2(wall_x - character.wall_side * 5.0, character.global_position.y - 3.0)
	var plane_x := character.wall_plane_local_x()
	var authored_wall_pose := String(character.anim_player.current_animation).begins_with("Wall/")
	if authored_wall_pose and action != &"WallRelease":
		# Wall clips are authored against a canonical right wall at local x=12.
		# Preserve edited offsets while translating the pose to the real wall plane.
		pelvis.position.x += plane_x - WALL_ANIMATION_REFERENCE_PLANE_X

	if action == &"WallHang":
		# Three-point support: main hand + high near foot + low assisting foot.
		if not authored_wall_pose:
			pelvis.position = pelvis.position.lerp(Vector2(plane_x - 11.0, -33.0), hang_weight)
			pelvis.rotation = lerp_angle(pelvis.rotation, deg_to_rad(-3.0), hang_weight)
			torso.position = torso.position.lerp(Vector2(2.0, -21.5), hang_weight)
			torso.rotation = lerp_angle(torso.rotation, deg_to_rad(8.0), hang_weight)
			if head: head.rotation = lerp_angle(head.rotation, deg_to_rad(-7.0), hang_weight)
			if is_instance_valid(upper_f): upper_f.position = upper_f.position.lerp(Vector2(4.0, -2.0), hang_weight)
		_solve_wall_chain(upper_f, fore_f, hand_f, main_hand_target, 1.0, hang_weight)
		_solve_wall_chain(upper_b, fore_b, hand_b, assist_hand_target, -1.0, hang_weight * 0.82)
		_solve_wall_chain(thigh_f, shin_f, foot_f, high_foot_target, 0.0, hang_weight)
		_solve_wall_chain(thigh_b, shin_b, foot_b, low_foot_target, 1.0, hang_weight * 0.88)
		_point_foot_at_wall(foot_f, hang_weight)
		_point_foot_at_wall(foot_b, hang_weight * 0.75)
	elif action == &"WallSlide":
		# The shoulder stays closer than the waist. Anchors descend slower than the
		# body, continuously opening the elbows and knees as friction stretches them.
		if not authored_wall_pose:
			pelvis.position = pelvis.position.lerp(Vector2(plane_x - 13.0, -32.0 + character.wall_slide_scrape_offset), 1.0)
			pelvis.rotation = lerp_angle(pelvis.rotation, deg_to_rad(-2.0), 1.0)
			torso.position = torso.position.lerp(Vector2(2.7, -21.0), 1.0)
			torso.rotation = lerp_angle(torso.rotation, deg_to_rad(12.0), 1.0)
			if head: head.rotation = lerp_angle(head.rotation, deg_to_rad(-9.0), 1.0)
		_solve_wall_chain(upper_f, fore_f, hand_f, main_hand_target, 1.0, 1.0)
		_solve_wall_chain(upper_b, fore_b, hand_b, assist_hand_target, -1.0, 0.72)
		# The wall-side foot stays planted while the knee pole opens away from the
		# wall, producing the readable hip -> outward knee -> wall foot Z shape.
		_solve_wall_chain(thigh_f, shin_f, foot_f, high_foot_target, 0.0, 1.0)
		_solve_wall_chain(thigh_b, shin_b, foot_b, low_foot_target, 1.0, 0.82)
		_point_foot_at_wall(foot_f, 1.0)
		_point_foot_at_wall(foot_b, 0.65)
	elif action == &"WallPush":
		var push_p := clampf(character.wall_action_time / maxf(character.wall_push_duration, 0.001), 0.0, 1.0)
		var extension := smoothstep(0.30, 1.0, push_p)
		var torso_release := smoothstep(0.62, 1.0, push_p)
		# First two frames compress 3 px into the wall; hip then drives away while
		# the fixed foot targets force knee extension. The hand releases last.
		if not authored_wall_pose:
			pelvis.position = pelvis.position.lerp(Vector2(plane_x - lerpf(7.0, 16.0, extension), lerpf(-30.0, -35.0, extension)), 1.0)
			pelvis.rotation = lerp_angle(pelvis.rotation, lerpf(deg_to_rad(3.0), deg_to_rad(-10.0), extension), 1.0)
			torso.position = torso.position.lerp(Vector2(lerpf(2.5, -1.5, torso_release), -21.0), 1.0)
			torso.rotation = lerp_angle(torso.rotation, lerpf(deg_to_rad(10.0), deg_to_rad(-14.0), torso_release), 1.0)
			if head: head.rotation = lerp_angle(head.rotation, lerpf(deg_to_rad(-8.0), deg_to_rad(9.0), torso_release), 1.0)
		_solve_wall_chain(upper_f, fore_f, hand_f, main_hand_target, 1.0, 1.0)
		_solve_wall_chain(upper_b, fore_b, hand_b, assist_hand_target, -1.0, 1.0 - torso_release * 0.45)
		_solve_wall_chain(thigh_f, shin_f, foot_f, high_foot_target, 0.0, 1.0)
		_solve_wall_chain(thigh_b, shin_b, foot_b, low_foot_target, 1.0, 1.0)
		_point_foot_at_wall(foot_f, smoothstep(0.55, 1.0, push_p))
		_point_foot_at_wall(foot_b, smoothstep(0.68, 1.0, push_p))
	elif action == &"WallRelease":
		var release_p := clampf(character.wall_action_time / maxf(character.wall_release_duration, 0.001), 0.0, 1.0)
		var body_hold := 1.0 - smoothstep(0.62, 1.0, release_p)
		var hand_hold := 1.0 - smoothstep(0.24, 0.72, release_p)
		if not authored_wall_pose:
			pelvis.position = pelvis.position.lerp(Vector2(-4.0, -35.0), body_hold)
			pelvis.rotation = lerp_angle(pelvis.rotation, deg_to_rad(-12.0), body_hold)
			torso.position = torso.position.lerp(Vector2(-1.5, -21.0), body_hold)
			torso.rotation = lerp_angle(torso.rotation, deg_to_rad(-15.0), body_hold)
			if head: head.rotation = lerp_angle(head.rotation, deg_to_rad(9.0), body_hold)
		_solve_wall_chain(upper_f, fore_f, hand_f, main_hand_target, 1.0, hand_hold)
		_solve_wall_chain(thigh_f, shin_f, foot_f, high_foot_target, 0.0, body_hold)
		if not authored_wall_pose:
			if is_instance_valid(thigh_b): thigh_b.rotation = lerp_angle(thigh_b.rotation, 0.70, body_hold)
			if is_instance_valid(shin_b): shin_b.rotation = lerp_angle(shin_b.rotation, -0.46, body_hold)
		_point_foot_at_wall(foot_f, body_hold)

func apply_block(w: float) -> void:
	var pelvis := character.skeleton.get_node_or_null("Pelvis") as Bone2D
	var torso := character.skeleton.get_node_or_null("Pelvis/Torso") as Bone2D
	var head := character.skeleton.get_node_or_null("Pelvis/Torso/Head") as Bone2D
	var upper_arm_f := character._upper_arm_front_bone
	var forearm_f := character._forearm_front_bone
	var hand_f := character._hand_front_bone
	var upper_arm_b := character._upper_arm_back_bone
	var forearm_b := character._forearm_back_bone
	var hand_b := character._hand_back_bone
	
	if not torso or not is_instance_valid(upper_arm_f) or not is_instance_valid(forearm_f):
		return
		
	if character.is_armed():
		# Armed Sword Guard (架住: 后脚撑地, 髋下沉, 前膝微屈, 胸略后仰, 剑挡在身前)
		torso.rotation = lerp_angle(torso.rotation, deg_to_rad(-3.0), w)
		torso.position = torso.position.lerp(Vector2(-0.5, -21.8), w)
		if head:
			head.position = head.position.lerp(Vector2(0.0, -13.0), w)
			head.rotation = lerp_angle(head.rotation, deg_to_rad(3.0), w)
		upper_arm_f.rotation = lerp_angle(upper_arm_f.rotation, -1.32, w)
		forearm_f.rotation = lerp_angle(forearm_f.rotation, -0.58, w)
		if is_instance_valid(hand_f): hand_f.rotation = lerp_angle(hand_f.rotation, 0.0, w)
		if is_instance_valid(upper_arm_b): upper_arm_b.rotation = lerp_angle(upper_arm_b.rotation, -1.10, w)
		if is_instance_valid(forearm_b): forearm_b.rotation = lerp_angle(forearm_b.rotation, -1.40, w)
		if is_instance_valid(hand_b): hand_b.rotation = lerp_angle(hand_b.rotation, 0.10, w)
	else:
		# Unarmed High Shell / Helmet Guard (缩住: 髋下沉6~8px, 前胸微倾, 下巴缩进, 双臂高位斜面护头)
		torso.rotation = lerp_angle(torso.rotation, deg_to_rad(5.0), w)
		torso.position = torso.position.lerp(Vector2(0.8, -21.4), w)
		if head:
			head.position = head.position.lerp(Vector2(0.2, -12.2), w)
			head.rotation = lerp_angle(head.rotation, deg_to_rad(-10.0), w)
		upper_arm_f.rotation = lerp_angle(upper_arm_f.rotation, -1.95, w)
		forearm_f.rotation = lerp_angle(forearm_f.rotation, -1.90, w)
		if is_instance_valid(hand_f): hand_f.rotation = lerp_angle(hand_f.rotation, 0.30, w)
		if is_instance_valid(upper_arm_b): upper_arm_b.rotation = lerp_angle(upper_arm_b.rotation, -1.75, w)
		if is_instance_valid(forearm_b): forearm_b.rotation = lerp_angle(forearm_b.rotation, -2.25, w)
		if is_instance_valid(hand_b): hand_b.rotation = lerp_angle(hand_b.rotation, 0.20, w)

	# Lower Body: Horse Stance (扎开马步)
	if is_instance_valid(pelvis) and character.is_on_floor():
		if character.state == &"Idle":
			var tf := character._thigh_front_bone
			var sf := character._shin_front_bone
			var ff := character._foot_front_bone
			var tb := character._thigh_back_bone
			var sb := character._shin_back_bone
			var fb := character._foot_back_bone
			
			if character.is_armed():
				# Armed stance: Pelvis sunk 4~6 px, front knee 10°~15°, rear knee 6°~10°
				pelvis.position.y = lerpf(pelvis.position.y, -30.5, w)
				pelvis.rotation = lerp_angle(pelvis.rotation, 0.0, w)
				if is_instance_valid(tf): tf.rotation = lerp_angle(tf.rotation, deg_to_rad(-22.0), w)
				if is_instance_valid(sf): sf.rotation = lerp_angle(sf.rotation, deg_to_rad(24.0), w)
				if is_instance_valid(ff): ff.rotation = lerp_angle(ff.rotation, -deg_to_rad(2.0), w)
				if is_instance_valid(tb): tb.rotation = lerp_angle(tb.rotation, deg_to_rad(6.0), w)
				if is_instance_valid(sb): sb.rotation = lerp_angle(sb.rotation, deg_to_rad(18.0), w)
				if is_instance_valid(fb): fb.rotation = lerp_angle(fb.rotation, -deg_to_rad(24.0), w)
			else:
				# Unarmed stance: Deeper crouch (6~8 px down), front knee 15°~20°, rear knee 10°~15°
				pelvis.position.y = lerpf(pelvis.position.y, -28.5, w)
				pelvis.rotation = lerp_angle(pelvis.rotation, 0.0, w)
				if is_instance_valid(tf): tf.rotation = lerp_angle(tf.rotation, deg_to_rad(-28.0), w)
				if is_instance_valid(sf): sf.rotation = lerp_angle(sf.rotation, deg_to_rad(30.0), w)
				if is_instance_valid(ff): ff.rotation = lerp_angle(ff.rotation, -deg_to_rad(2.0), w)
				if is_instance_valid(tb): tb.rotation = lerp_angle(tb.rotation, deg_to_rad(4.0), w)
				if is_instance_valid(sb): sb.rotation = lerp_angle(sb.rotation, deg_to_rad(24.0), w)
				if is_instance_valid(fb): fb.rotation = lerp_angle(fb.rotation, -deg_to_rad(28.0), w)
		else:
			# Guard Walk: sink pelvis slightly to maintain low defensive posture during locomotion
			pelvis.position.y = lerpf(pelvis.position.y, pelvis.position.y + 2.5, w)

func apply_action() -> void:
	var clip := character.anim_player.get_animation(character.attack_animation())
	var t := character.attack_time
	var sample_time := t
	# A short visual impact hold leaves physics, gait and damage timing running.
	if character.is_armed() and character.combo_stage == 2:
		var hit_time := clip.length*.54
		var hold_end: float = hit_time+blade_footwork.heavy_hold_seconds
		if t >= hit_time and t < hold_end: sample_time = hit_time
		elif t >= hold_end: sample_time = lerpf(hit_time,clip.length,(t-hold_end)/maxf(clip.length-hold_end,.001))
	weight = smoothstep(0.0,attack_blend_in,t) * (1.0-smoothstep(clip.length*recovery_start,clip.length,t))
	var pelvis := character.skeleton.get_node("Pelvis") as Bone2D
	var is_unarmed_stationary: bool = not character.is_armed() and character.state == &"Idle" and character.is_on_floor()
	var legs: Dictionary = {}
	if not is_unarmed_stationary:
		for side in ["Front","Back"]:
			var leg := pelvis.get_node("Thigh"+side) as Bone2D
			legs[leg] = leg.global_transform
	for track in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_VALUE or not clip.track_is_enabled(track): continue
		var target := String(clip.track_get_path(track)).split(":")
		if target.size() != 2: continue
		var node := character.get_node_or_null(NodePath(target[0]))
		var property := target[1]
		var value = clip.value_track_interpolate(track,sample_time)
		if node == pelvis:
			if property == "rotation":
				if is_unarmed_stationary:
					pelvis.rotation = lerp_angle(pelvis.rotation, float(value), weight)
				else:
					var limit := idle_pelvis_limit if character.state == &"Idle" else (air_pelvis_limit if character.state in [&"Jump",&"Fall"] else (0.18 if not character.is_armed() else moving_pelvis_limit))
					pelvis.rotation += clampf(float(value)-.04,-limit,limit)*weight
			elif property == "position" and is_unarmed_stationary:
				pelvis.position = pelvis.position.lerp(value, weight)
		elif node is Bone2D and "/Torso" in target[0]:
			if property == "rotation": node.rotation = lerp_angle(node.rotation,float(value),weight)
			elif property == "position": node.position = node.position.lerp(value,weight)
		elif node is Bone2D and is_unarmed_stationary and ("/Thigh" in target[0] or "/Shin" in target[0] or "/Foot" in target[0]):
			if property == "rotation": node.rotation = lerp_angle(node.rotation,float(value),weight)
		elif node == character.weapons and property in ["blade_projection","blade_depth"]:
			node.set(property,lerpf(float(node.get(property)),float(value),weight))
	# Compensate for pelvis vertical bob on torso during punches to stabilize active punch height
	var torso := character.skeleton.get_node_or_null("Pelvis/Torso") as Bone2D
	if torso:
		if not character.is_armed() and character.state in [&"Walk", &"Run"]:
			var locomotion_bob_y: float = pelvis.position.y - (-33.0)
			torso.position.y += -locomotion_bob_y * 0.4 * weight
		if "impact_accent_offset" in character:
			torso.position += character.impact_accent_offset * weight
		if character.hit_stop_duration > 0.0 or character.hit_drag_timer > 0.0:
			var wrist: Bone2D = character._hand_front_bone if is_instance_valid(character._hand_front_bone) else null
			if wrist:
				wrist.position.x += -1.2 * weight
			torso.rotation += -0.06 * weight
	# The shared pelvis twist must not rotate hip offsets, knees or planted feet during locomotion or blade attacks.
	if not is_unarmed_stationary:
		var active_damping: float = 0.12 * weight if (not character.is_armed() and character.state in [&"Walk", &"Run"]) else 0.0
		for leg in legs:
			leg.global_transform = legs[leg]
			if active_damping > 0.0:
				leg.rotation = lerpf(leg.rotation, 0.0, active_damping)
	if character.is_armed() and character.weapons.current.weapon_class == "blade":
		apply_blade_footwork(clip.length)

func apply_blade_footwork(duration: float) -> void:
	lower_body_weight = blade_footwork.influence(character.state) if character.is_on_floor() else 0.0
	if lower_body_weight <= 0: return
	var pelvis := character.skeleton.get_node("Pelvis") as Bone2D
	var feet: Dictionary = {}
	var rolls: Dictionary = {}
	for side in ["Front","Back"]:
		var foot := pelvis.get_node("Thigh%s/Shin%s/Foot%s" % [side,side,side]) as Bone2D
		feet[side] = character.visual.to_local(foot.global_position)
		rolls[side] = foot.global_rotation-character.visual.global_rotation
	if character.combo_stage != last_action_stage or character.attack_time < last_action_time:
		footwork_lead = "Front" if feet["Front"].x >= feet["Back"].x else "Back"
	last_action_time = character.attack_time
	last_action_stage = character.combo_stage
	var offsets: Dictionary = blade_footwork.sample(character.combo_stage,character.attack_time/maxf(duration,.001))
	pelvis.position += offsets.pelvis*lower_body_weight
	for side in feet:
		feet[side] += (offsets.front if side == footwork_lead else offsets.back)*lower_body_weight
		if side != footwork_lead:
			var heel: float = offsets.heel*lower_body_weight
			rolls[side] += heel
			feet[side].y -= sin(heel)*4.2
	# Lower the pelvis only as far as needed to keep the rear leg reachable.
	for side in feet:
		var thigh := pelvis.get_node("Thigh"+side) as Bone2D
		var shin := thigh.get_node("Shin"+side) as Bone2D
		var foot := shin.get_node("Foot"+side) as Bone2D
		var hip := character.visual.to_local(thigh.global_position)
		var reach := (shin.position.length()+foot.position.length())*.997
		var dx: float = feet[side].x-hip.x
		pelvis.position.y += maxf(0.0,feet[side].y-sqrt(maxf(1.0,reach*reach-dx*dx))-hip.y)
	for side in feet:
		var thigh := pelvis.get_node("Thigh"+side) as Bone2D
		var shin := thigh.get_node("Shin"+side) as Bone2D
		var foot := shin.get_node("Foot"+side) as Bone2D
		var hip := character.visual.to_local(thigh.global_position)
		var delta: Vector2 = feet[side]-hip
		var a := shin.position.length()
		var b := foot.position.length()
		var d := clampf(delta.length(),absf(a-b)+.01,a+b-.01)
		var bend := PI-acos(clampf((a*a+b*b-d*d)/(2*a*b),-1,1))
		var direction := atan2(-delta.x,delta.y)-acos(clampf((a*a+d*d-b*b)/(2*a*d),-1,1))
		thigh.rotation = direction-(pelvis.global_rotation-character.visual.global_rotation)
		shin.rotation = bend
		foot.rotation = rolls[side]-direction-bend

func apply_reaction(_delta: float) -> void:
	if not character or not character.has_reaction(): return
	var t: float = character.reaction_time
	var dur: float = maxf(character.reaction_duration, 0.001)
	var p: float = clampf(t / dur, 0.0, 1.0)
	
	# Two-phase recoil curves:
	# 1. Linear Push (Immediate on contact, 0.0 to 0.18): whole body displaced along attack direction
	# 2. Rotational Strain (Lags behind, peaks 0.25 to 0.40): torso & head arch backward
	var push_weight: float = 0.0
	var rot_weight: float = 0.0
	
	if p < 0.18:
		push_weight = sin(p / 0.18 * PI * 0.5)
		rot_weight = smoothstep(0.06, 0.18, p) * 0.35
	else:
		var decay_p := (p - 0.18) / 0.82
		push_weight = cos(decay_p * PI * 0.5) * exp(-decay_p * 1.5)
		if p < 0.38:
			rot_weight = 0.35 + 0.65 * sin((p - 0.18) / 0.20 * PI * 0.5)
		else:
			var decay_rot := (p - 0.38) / 0.62
			rot_weight = cos(decay_rot * PI * 0.5) * exp(-decay_rot * 2.2)

	push_weight = clampf(push_weight, 0.0, 1.3) * character.reaction_intensity
	rot_weight = clampf(rot_weight, 0.0, 1.3) * character.reaction_intensity
	
	# Direction mapping in local space (facing: 1 or -1)
	var local_x: float = character.reaction_direction.x * character.facing
	var local_y: float = character.reaction_direction.y
	var local_dir := Vector2(local_x, local_y)
	
	var pelvis := character.skeleton.get_node_or_null("Pelvis") as Bone2D
	var torso := character.skeleton.get_node_or_null("Pelvis/Torso") as Bone2D
	var head := character.skeleton.get_node_or_null("Pelvis/Torso/Head") as Bone2D
	if not pelvis or not torso or not head: return
	
	var tier: StringName = character.reaction_state
	var region: StringName = character.reaction_region
	
	if tier == &"BlockHit":
		_apply_block_hit_shockwave(p, local_dir)
		return
		
	var tier_scale := 1.0
	match tier:
		&"MicroHit": tier_scale = 0.35
		&"LightHit": tier_scale = 1.0
		&"AirHit": tier_scale = 1.15
		&"HeavyHit": tier_scale = 1.85
		&"Knockdown": tier_scale = 2.4
		
	var w_push := push_weight * tier_scale
	var w_rot := rot_weight * tier_scale
	
	match region:
		&"HEAD":
			head.rotation += local_dir.x * 0.28 * w_rot
			head.position += Vector2(local_dir.x * 3.5, local_dir.y * 1.5) * w_push
			torso.rotation += local_dir.x * 0.12 * w_rot
			torso.position += Vector2(local_dir.x * 1.8, local_dir.y * 0.8) * w_push
			pelvis.position.x += local_dir.x * 0.8 * w_push
		&"LOWER_TORSO", &"LEG":
			pelvis.position += Vector2(local_dir.x * 2.8, local_dir.y * 1.4) * w_push
			pelvis.rotation += local_dir.x * 0.08 * w_rot
			torso.position += Vector2(local_dir.x * 1.8, local_dir.y * 0.8) * w_push
			head.position += Vector2(local_dir.x * 1.0, 0.0) * w_push
		_: # UPPER_TORSO
			torso.rotation += local_dir.x * 0.24 * w_rot
			torso.position += Vector2(local_dir.x * 4.2, local_dir.y * 1.8) * w_push
			head.position += Vector2(local_dir.x * 2.4, local_dir.y * 1.0) * w_push
			head.rotation += -local_dir.x * 0.08 * w_rot
			pelvis.position.x += local_dir.x * 1.6 * w_push
			
	if tier in [&"HeavyHit", &"Knockdown"]:
		torso.rotation += local_dir.x * 0.18 * w_rot
		pelvis.position.y += 2.0 * w_rot

func _apply_block_hit_shockwave(p: float, local_dir: Vector2) -> void:
	# Kinetic Impact Wave:
	# Frame 0: Contact
	# Frame 1: Sword deflecting backward 4°~7° / Forearms compressing inward 2~3px
	# Frame 2: Hands displace backward 2~3px, Torso pitches back 2°
	# Frame 3: Pelvis shifts back 1px, Front knee flexes deeper (eats momentum)
	# Frame 4-6: Rebound smoothly to guard_idle
	# "手臂可以后退，脚不要跟着滑。脚是锚。"
	
	# Sub-phase curves:
	# 1. Arm/Weapon peak early (frames 1-2, p ~ 0.0 to 0.50)
	var w_arm: float = sin(clampf(p / 0.50, 0.0, 1.0) * PI) * exp(-p * 1.5)
	# 2. Torso/Shoulder peak middle (frames 2-3, p ~ 0.04 to 0.65)
	var w_torso: float = sin(clampf((p - 0.04) / 0.60, 0.0, 1.0) * PI) * exp(-(p - 0.04) * 1.5) if p >= 0.04 else 0.0
	# 3. Pelvis/Knees peak later (frames 3-4, p ~ 0.12 to 0.85)
	var w_pelvis: float = sin(clampf((p - 0.12) / 0.70, 0.0, 1.0) * PI) * exp(-(p - 0.12) * 1.2) if p >= 0.12 else 0.0

	var pelvis := character.skeleton.get_node_or_null("Pelvis") as Bone2D
	var torso := character.skeleton.get_node_or_null("Pelvis/Torso") as Bone2D
	var head := character.skeleton.get_node_or_null("Pelvis/Torso/Head") as Bone2D
	var hf := character._hand_front_bone
	var hb := character._hand_back_bone
	var faf := character._forearm_front_bone
	var fab := character._forearm_back_bone
	var tf := character._thigh_front_bone
	var sf := character._shin_front_bone
	var ff := character._foot_front_bone
	var tb := character._thigh_back_bone
	var sb := character._shin_back_bone
	
	var push_x: float = local_dir.x # e.g. -1.0 for frontal incoming strike
	
	# 1. Arms shock
	if character.is_armed():
		if is_instance_valid(hf): hf.position.x += push_x * 2.5 * w_arm
		if is_instance_valid(hb): hb.position.x += push_x * 2.0 * w_arm
	else:
		if is_instance_valid(faf): faf.rotation += push_x * deg_to_rad(5.0) * w_arm
		if is_instance_valid(fab): fab.rotation += push_x * deg_to_rad(4.0) * w_arm
		if is_instance_valid(hf): hf.position.x += push_x * 2.2 * w_arm
		if is_instance_valid(hb): hb.position.x += push_x * 1.8 * w_arm
		
	# 2. Torso & Head shock
	if is_instance_valid(torso):
		torso.position.x += push_x * 2.0 * w_torso
		torso.rotation += push_x * deg_to_rad(2.0) * w_torso
	if is_instance_valid(head):
		head.position.y += 0.8 * w_torso
		head.rotation += push_x * deg_to_rad(2.5) * w_torso
		
	# 3. Pelvis & Knees absorption (Feet stay firmly grounded!)
	if is_instance_valid(pelvis):
		pelvis.position.x += push_x * 1.0 * w_pelvis
	if is_instance_valid(sf):
		sf.rotation += deg_to_rad(6.0) * w_pelvis
	if is_instance_valid(tf):
		tf.rotation -= deg_to_rad(4.0) * w_pelvis
	if is_instance_valid(ff):
		ff.rotation -= deg_to_rad(2.0) * w_pelvis
		
	# Directional Additive Recoil:
	# Overhead / Downward strike (local_dir.y > 0.3)
	if local_dir.y > 0.3:
		var w_down: float = local_dir.y * w_torso
		if is_instance_valid(pelvis): pelvis.position.y += 2.0 * w_down
		if is_instance_valid(sf): sf.rotation += deg_to_rad(8.0) * w_down
		if is_instance_valid(sb): sb.rotation += deg_to_rad(6.0) * w_down
		if is_instance_valid(hf): hf.position.y += 2.0 * w_down
		if is_instance_valid(hb): hb.position.y += 1.5 * w_down
	# Low / Uppercut strike (local_dir.y < -0.3)
	elif local_dir.y < -0.3:
		var w_up: float = -local_dir.y * w_torso
		if is_instance_valid(torso): torso.rotation += deg_to_rad(4.0) * w_up
		if is_instance_valid(head): head.rotation += deg_to_rad(6.0) * w_up
		if is_instance_valid(tf): tf.rotation += deg_to_rad(4.0) * w_up

func _draw() -> void:
	if not is_instance_valid(character) or not character.rig or not character.rig.debug_draw: return
	for bone in base_pose:
		var color := Color("48dca4")
		if bone.name == "Pelvis": color = Color("ffd467")
		elif "/Torso" in String(bone.get_path()): color = Color("ff8697") if weight > 0 else Color("48dca4")
		var origin := to_local(bone.global_position)
		draw_circle(origin,1.6,color)
		for child in bone.get_children():
			if child is Bone2D: draw_line(origin,to_local(child.global_position),color,1.0)
