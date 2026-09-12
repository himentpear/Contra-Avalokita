class_name MudBodyRenderer
extends Node2D
const MAX_SEGMENTS := 40
@export var mud_color := Color("737f45")
@export_range(0.1, 4.0) var fusion_softness := 1.8
@export var render_bounds := Rect2(-80, -104, 160, 128)
@export_range(0.5, 2.0) var edge_width := 1.0
@export_range(0.0, 0.05) var surface_noise := 0.025
@export_group("Proportions")
@export var head_radius := 8.2
@export var body_radius := 9.0
@export var arm_radius := 3.7
@export var leg_radius := 5.0
@export var auxiliary_distance := 3.2
var weapon_arm_depth := 1.0
var offhand_arm_depth := -1.0
var facing_depth := 1.0
var depth_materials: Array[ShaderMaterial] = []
var shared_uniforms: Array[StringName] = []

var impact_center := Vector2.ZERO
var impact_radius := 0.0
var impact_depth := 0.0
var impact_bulge_center := Vector2.ZERO
var impact_bulge_radius := 0.0
var impact_bulge_height := 0.0
var impact_ripple_phase := 0.0

@export_group("Death Collapse")
@export var death_progress := 0.0
@export var torso_squash_ratio := 0.20
@export var puddle_spread_ratio := 2.4
@export var limb_retraction_strength := 0.85

var shader_material: ShaderMaterial
var endpoints := PackedVector4Array()
var properties := PackedVector4Array()
var segments: Array[MudSegment] = []
var segment_cursor := 0
var compressions: Dictionary = {}
var angles: Dictionary = {}
var auxiliary_points: Dictionary = {}

var _bones_cached := false
var _bone_pelvis: Bone2D
var _bone_torso: Bone2D
var _bone_head: Bone2D
var _bone_upper_arm_front: Bone2D
var _bone_forearm_front: Bone2D
var _bone_hand_front: Bone2D
var _bone_upper_arm_back: Bone2D
var _bone_forearm_back: Bone2D
var _bone_hand_back: Bone2D
var _bone_thigh_front: Bone2D
var _bone_shin_front: Bone2D
var _bone_foot_front: Bone2D
var _bone_thigh_back: Bone2D
var _bone_shin_back: Bone2D
var _bone_foot_back: Bone2D

func _ready() -> void:
	endpoints.resize(MAX_SEGMENTS)
	properties.resize(MAX_SEGMENTS)
	var surface := ColorRect.new()
	surface.position = render_bounds.position
	surface.size = render_bounds.size
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://shaders/mud_pixel_shader.gdshader")
	surface.material = shader_material
	add_child(surface)
	shader_material.set_shader_parameter("bounds_origin", render_bounds.position)
	shader_material.set_shader_parameter("bounds_size", render_bounds.size)
	shader_material.set_shader_parameter("depth_pass",0)
	for uniform in shader_material.shader.get_shader_uniform_list():
		if uniform.name != "depth_pass": shared_uniforms.append(StringName(uniform.name))
	for depth in [-1,1]:
		var layer := ColorRect.new()
		layer.name = "RearSurface" if depth < 0 else "FrontSurface"
		layer.position = render_bounds.position
		layer.size = render_bounds.size
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.z_index = -6 if depth < 0 else 4
		var material := shader_material.duplicate() as ShaderMaterial
		material.set_shader_parameter("depth_pass",depth)
		layer.material = material
		add_child(layer)
		depth_materials.append(material)

func sync_depth_materials() -> void:
	for material in depth_materials:
		for uniform in shared_uniforms:
			material.set_shader_parameter(uniform,shader_material.get_shader_parameter(uniform))

func cache_bones(skeleton: Skeleton2D) -> void:
	if not skeleton: return
	_bone_pelvis = skeleton.get_node_or_null("Pelvis") as Bone2D
	if _bone_pelvis:
		_bone_torso = _bone_pelvis.get_node_or_null("Torso") as Bone2D
		_bone_thigh_front = _bone_pelvis.get_node_or_null("ThighFront") as Bone2D
		_bone_thigh_back = _bone_pelvis.get_node_or_null("ThighBack") as Bone2D
	if _bone_torso:
		_bone_head = _bone_torso.get_node_or_null("Head") as Bone2D
		_bone_upper_arm_front = _bone_torso.get_node_or_null("UpperArmFront") as Bone2D
		_bone_upper_arm_back = _bone_torso.get_node_or_null("UpperArmBack") as Bone2D
	if _bone_upper_arm_front:
		_bone_forearm_front = _bone_upper_arm_front.get_node_or_null("ForearmFront") as Bone2D
	if _bone_forearm_front:
		_bone_hand_front = _bone_forearm_front.get_node_or_null("HandFront") as Bone2D
	if _bone_upper_arm_back:
		_bone_forearm_back = _bone_upper_arm_back.get_node_or_null("ForearmBack") as Bone2D
	if _bone_forearm_back:
		_bone_hand_back = _bone_forearm_back.get_node_or_null("HandBack") as Bone2D
	if _bone_thigh_front:
		_bone_shin_front = _bone_thigh_front.get_node_or_null("ShinFront") as Bone2D
	if _bone_shin_front:
		_bone_foot_front = _bone_shin_front.get_node_or_null("FootFront") as Bone2D
	if _bone_thigh_back:
		_bone_shin_back = _bone_thigh_back.get_node_or_null("ShinBack") as Bone2D
	if _bone_shin_back:
		_bone_foot_back = _bone_shin_back.get_node_or_null("FootBack") as Bone2D
	_bones_cached = true

func point(id: StringName) -> Vector2:
	if auxiliary_points.has(id):
		return auxiliary_points[id]
	return Vector2.ZERO

func add_segment(a: Vector2, b: Vector2, r1: float, r2: float, depth := 0.0) -> void:
	if segment_cursor == segments.size():
		segments.append(MudSegment.new())
	var s := segments[segment_cursor]
	segment_cursor += 1
	s.start_position = a
	s.end_position = b
	s.radius_start = r1
	s.radius_end = r2
	s.depth = depth

func _solve_arm(id: String, upper_bone: Bone2D, fore_bone: Bone2D, hand_bone: Bone2D, depth: float) -> void:
	if not upper_bone or not fore_bone or not hand_bone: return
	var origin := to_local(upper_bone.global_position)
	var joint := to_local(fore_bone.global_position)
	var end := to_local(hand_bone.global_position)
	
	if death_progress > 0.0 and _bone_pelvis:
		var pelvis_pos := to_local(_bone_pelvis.global_position)
		var retract := clampf(death_progress * limb_retraction_strength, 0.0, 0.95)
		origin = origin.lerp(pelvis_pos, retract)
		joint = joint.lerp(pelvis_pos, retract)
		end = end.lerp(pelvis_pos, retract)
	
	var u := (joint - origin).normalized()
	if u.length_squared() < 0.001: u = Vector2.DOWN
	var v := (end - joint).normalized()
	if v.length_squared() < 0.001: v = u
	
	var bend := u.angle_to(v)
	bend = clampf(bend, -deg_to_rad(140.0), deg_to_rad(140.0))
	var compression := MudJointSolver.compression_for(bend)
	angles[id] = rad_to_deg(absf(bend))
	compressions[id] = compression
	
	var diff := -(u - v)
	var outer := diff.normalized() * (compression * 0.7) if diff.length_squared() > 0.001 else Vector2.ZERO
	var pre := joint - u * auxiliary_distance + outer
	var post := joint + v * auxiliary_distance + outer
	
	auxiliary_points[StringName(id + "Start")] = origin
	auxiliary_points[StringName(id + "Joint")] = joint
	auxiliary_points[StringName(id + "Pre")] = pre
	auxiliary_points[StringName(id + "Post")] = post
	auxiliary_points[StringName(id + "End")] = end
	
	var r := arm_radius * (0.88 if depth < 0 else 1.0)
	if death_progress > 0.0:
		r *= lerpf(1.0, 0.4, death_progress)
	var jr := r * (1.0 - compression * 0.14)
	
	add_segment(origin, pre, r, jr, depth)
	add_segment(pre, joint + outer, jr, jr, depth)
	add_segment(joint + outer, post, jr, jr, depth)
	add_segment(post, end, jr, r * 0.78, depth)
	add_segment(end, end + v * 2.0, r, r * 0.9, depth)

func _solve_leg(id: String, thigh_bone: Bone2D, shin_bone: Bone2D, foot_bone: Bone2D, depth: float) -> void:
	if not thigh_bone or not shin_bone or not foot_bone: return
	var origin := to_local(thigh_bone.global_position)
	var joint := to_local(shin_bone.global_position)
	var end := to_local(foot_bone.global_position)
	
	if death_progress > 0.0 and _bone_pelvis:
		var pelvis_pos := to_local(_bone_pelvis.global_position)
		var retract := clampf(death_progress * limb_retraction_strength, 0.0, 0.95)
		origin = origin.lerp(pelvis_pos, retract)
		joint = joint.lerp(pelvis_pos, retract)
		end = end.lerp(pelvis_pos, retract)
	
	var u := (joint - origin).normalized()
	if u.length_squared() < 0.001: u = Vector2.DOWN
	var v := (end - joint).normalized()
	if v.length_squared() < 0.001: v = u
	
	var bend := u.angle_to(v)
	bend = clampf(bend, -deg_to_rad(140.0), deg_to_rad(140.0))
	var compression := MudJointSolver.compression_for(bend)
	angles[id] = rad_to_deg(absf(bend))
	compressions[id] = compression
	
	var diff := -(u - v)
	var outer := diff.normalized() * (compression * 0.7) if diff.length_squared() > 0.001 else Vector2.ZERO
	var pre := joint - u * auxiliary_distance + outer
	var post := joint + v * auxiliary_distance + outer
	
	auxiliary_points[StringName(id + "Start")] = origin
	auxiliary_points[StringName(id + "Joint")] = joint
	auxiliary_points[StringName(id + "Pre")] = pre
	auxiliary_points[StringName(id + "Post")] = post
	auxiliary_points[StringName(id + "End")] = end
	
	var r := leg_radius * (0.88 if depth < 0 else 1.0)
	if death_progress > 0.0:
		r *= lerpf(1.0, 0.4, death_progress)
	# Knee volume: soft joint compression expands outer knee silhouette
	var knee_expansion := 1.0 + compression * 0.18
	var jr := r * (1.0 - compression * 0.14) * knee_expansion
	
	# Calf volume: expands under flexion and weight push
	var calf_radius := r * (1.0 + compression * 0.12)
	
	add_segment(origin, pre, r, jr, depth)
	add_segment(pre, joint + outer, jr, jr, depth)
	add_segment(joint + outer, post, jr, calf_radius, depth)
	add_segment(post, end, calf_radius, r * 0.78, depth)
	
	var foot_rot := foot_bone.global_rotation - global_rotation
	var axis := Vector2.RIGHT.rotated(foot_rot)
	var heel := end - axis
	var ball := end + axis * 2.6
	var toe := end + axis * 4.2
	auxiliary_points[StringName(id + "Heel")] = heel
	auxiliary_points[StringName(id + "Foot")] = ball
	auxiliary_points[StringName(id + "Toe")] = toe
	
	# Foot squash: sole expands horizontally and flattens on ground contact
	var foot_contact_weight := clampf(1.0 - absf(foot_rot) * 1.6, 0.0, 1.0)
	var sole_radius := (2.8 + foot_contact_weight * 0.45) * (lerpf(1.0, 0.3, death_progress) if death_progress > 0.0 else 1.0)
	add_segment(heel, ball, sole_radius, sole_radius, depth)
	add_segment(ball, toe, sole_radius, maxf(1.8, sole_radius - 0.35), depth)

func sync_skeleton(skeleton: Skeleton2D, _delta: float = 0.0) -> void:
	if not _bones_cached or not _bone_pelvis:
		cache_bones(skeleton)
	if not _bone_pelvis or not _bone_torso or not _bone_head: return
	
	segment_cursor = 0
	
	var pelvis_pos := to_local(_bone_pelvis.global_position)
	var torso_pos := to_local(_bone_torso.global_position)
	var head_pos := to_local(_bone_head.global_position)
	var abdomen_pos := pelvis_pos.lerp(torso_pos, 0.46)
	
	auxiliary_points[&"Pelvis"] = pelvis_pos
	auxiliary_points[&"Torso"] = torso_pos
	auxiliary_points[&"Abdomen"] = abdomen_pos
	auxiliary_points[&"Head"] = head_pos
	auxiliary_points[&"Chest"] = torso_pos
	auxiliary_points[&"Neck"] = torso_pos.lerp(head_pos, 0.5)
	
	# 1. Back leg (depth -1.0)
	_solve_leg("LegBack", _bone_thigh_back, _bone_shin_back, _bone_foot_back, -facing_depth)
	
	# 2. Back arm (depth -1.0)
	_solve_arm("ArmBack", _bone_upper_arm_back, _bone_forearm_back, _bone_hand_back, offhand_arm_depth)
	
	# 3. Torso and Head (depth 0.0)
	var torso_r := body_radius
	var h_r := head_radius
	if death_progress > 0.0:
		torso_r = lerpf(body_radius, body_radius * 1.3, death_progress)
		h_r = lerpf(head_radius, head_radius * 0.7, death_progress)
	add_segment(pelvis_pos, abdomen_pos, torso_r, torso_r * 0.86, 0.0)
	add_segment(abdomen_pos, torso_pos, torso_r * 0.86, torso_r, 0.0)
	add_segment(torso_pos, head_pos, 4.0, 4.0, 0.0)
	add_segment(head_pos + Vector2(0, -1), head_pos + Vector2(0, 1), h_r, h_r, 0.0)
	
	# 4. Front leg (depth 1.0)
	_solve_leg("LegFront", _bone_thigh_front, _bone_shin_front, _bone_foot_front, facing_depth)
	
	# 5. Front arm (depth 1.0)
	_solve_arm("ArmFront", _bone_upper_arm_front, _bone_forearm_front, _bone_hand_front, weapon_arm_depth)
	
	# 6. Death puddle generation
	if death_progress > 0.15:
		var p_puddle := clampf((death_progress - 0.15) / 0.70, 0.0, 1.0)
		p_puddle = ease(p_puddle, 0.5)
		var max_spread := 28.0 * puddle_spread_ratio / 2.4
		var spread_x := lerpf(4.0, max_spread, p_puddle)
		var puddle_h := lerpf(5.0, 3.2, p_puddle)
		add_segment(Vector2(-spread_x, -2.0), Vector2(spread_x, -2.0), puddle_h, puddle_h * 0.95, 0.0)
		add_segment(Vector2(-spread_x * 0.75, -2.5), Vector2(spread_x * 0.65, -2.5), puddle_h * 0.85, puddle_h * 0.75, 0.0)
		add_segment(Vector2(-spread_x * 0.3, -3.0), Vector2(spread_x * 0.4, -3.0), puddle_h * 0.9, puddle_h * 0.8, 0.0)
	
	_upload_segments()
	sync_depth_materials()

func _upload_segments() -> void:
	var count := mini(segment_cursor, MAX_SEGMENTS)
	for i in count:
		var s := segments[i]
		endpoints[i] = Vector4(s.start_position.x, s.start_position.y, s.end_position.x, s.end_position.y)
		properties[i] = Vector4(s.radius_start, s.radius_end, fusion_softness, s.depth)
	shader_material.set_shader_parameter("segment_count", count)
	shader_material.set_shader_parameter("endpoints", endpoints)
	shader_material.set_shader_parameter("properties", properties)
	shader_material.set_shader_parameter("mud_color", mud_color)
	shader_material.set_shader_parameter("edge_width", edge_width)
	shader_material.set_shader_parameter("noise_strength", surface_noise)
	shader_material.set_shader_parameter("impact_params", Vector4(impact_center.x, impact_center.y, impact_radius, impact_depth))
	shader_material.set_shader_parameter("impact_bulge", Vector4(impact_bulge_center.x, impact_bulge_center.y, impact_bulge_radius, impact_bulge_height))
	shader_material.set_shader_parameter("impact_ripple_phase", impact_ripple_phase)

func sync(rig: MudRig) -> void:
	if not rig: return
	# Legacy preview callers upload below; mirror those uniforms before drawing too.
	call_deferred("sync_depth_materials")
	assert(rig.segments.size() <= MAX_SEGMENTS, "Increase shader and CPU capacity together.")
	for i in rig.segments.size():
		var s := rig.segments[i]
		endpoints[i] = Vector4(s.start_position.x, s.start_position.y, s.end_position.x, s.end_position.y)
		properties[i] = Vector4(s.radius_start, s.radius_end, fusion_softness, s.depth)
	shader_material.set_shader_parameter("segment_count", rig.segments.size())
	shader_material.set_shader_parameter("endpoints", endpoints)
	shader_material.set_shader_parameter("properties", properties)
	shader_material.set_shader_parameter("mud_color", mud_color)
	shader_material.set_shader_parameter("edge_width", edge_width)
	shader_material.set_shader_parameter("noise_strength", surface_noise)
	shader_material.set_shader_parameter("impact_params", Vector4(impact_center.x, impact_center.y, impact_radius, impact_depth))
	shader_material.set_shader_parameter("impact_bulge", Vector4(impact_bulge_center.x, impact_bulge_center.y, impact_bulge_radius, impact_bulge_height))
	shader_material.set_shader_parameter("impact_ripple_phase", impact_ripple_phase)
