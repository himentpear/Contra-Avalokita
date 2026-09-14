@tool
class_name RotoLegacyAnimationConverter
extends RefCounted


func convert(player: AnimationPlayer, skeleton: Skeleton2D, semantic_map: Dictionary, animation_name: StringName, sample_times: PackedFloat32Array) -> RotoPoseGraph:
	var graph := RotoPoseGraph.new()
	graph.graph_name = animation_name
	graph.intent = "legacy_pose_approximation"
	if player == null or skeleton == null or not player.has_animation(animation_name):
		return graph
	if sample_times.is_empty():
		sample_times = extract_important_times(player.get_animation(animation_name))
	var previous_animation := player.assigned_animation
	var previous_time := player.current_animation_position
	for index in sample_times.size():
		player.play(animation_name)
		player.seek(sample_times[index], true)
		player.pause()
		var pose := _capture_pose(skeleton, semantic_map, sample_times[index], "pose_%02d" % index)
		var node := RotoPoseNode.new()
		node.node_id = pose.pose_name
		node.display_name = String(pose.pose_name).capitalize()
		node.pose = pose
		node.marker_type = RotoPoseNode.MarkerType.EXTREME if index == 0 else RotoPoseNode.MarkerType.BREAKDOWN
		node.meaning = "Approximation sampled from legacy animation at %.3fs" % sample_times[index]
		if index + 1 < sample_times.size():
			node.next_nodes = PackedStringArray(["pose_%02d" % (index + 1)])
		graph.add_node(node)
	if not previous_animation.is_empty() and player.has_animation(previous_animation):
		player.play(previous_animation)
		player.seek(previous_time, true)
		player.pause()
	else:
		player.stop()
	return graph


func extract_important_times(animation: Animation, max_poses := 8) -> PackedFloat32Array:
	max_poses = maxi(max_poses, 2)
	var unique_times: Array[float] = [0.0]
	if animation == null:
		return PackedFloat32Array(unique_times)
	for track in animation.get_track_count():
		for key in animation.track_get_key_count(track):
			var time := animation.track_get_key_time(track, key)
			if not unique_times.has(time):
				unique_times.append(time)
	unique_times.sort()
	if unique_times.size() <= max_poses:
		return PackedFloat32Array(unique_times)
	var reduced := PackedFloat32Array()
	for index in max_poses:
		var source_index := roundi(index * (unique_times.size() - 1.0) / (max_poses - 1.0))
		reduced.append(unique_times[source_index])
	return reduced


func build_playback_animation(graph: RotoPoseGraph, controller_path: NodePath) -> Animation:
	var animation := Animation.new()
	var nodes := graph.sorted_nodes()
	if nodes.is_empty():
		return animation
	animation.length = maxf(nodes[-1].pose.time + 0.001, 0.001)
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(String(controller_path) + ":current_pose"))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	for node in nodes:
		animation.track_insert_key(track, node.pose.time, node.pose)
	return animation


func _capture_pose(skeleton: Skeleton2D, semantic_map: Dictionary, time: float, pose_name: String) -> RotoPose:
	var pose := RotoPose.new()
	pose.pose_name = StringName(pose_name)
	pose.time = time
	for target_name in ["head", "hand_r", "hand_l", "foot_r", "foot_l"]:
		var path := NodePath(String(semantic_map.get(target_name, "")))
		var bone := skeleton.get_node_or_null(path) as Bone2D if not path.is_empty() else null
		if bone != null:
			pose.set_target(StringName(target_name), skeleton.to_local(bone.global_position))
	var body_path := NodePath(String(semantic_map.get("body", "")))
	var body := skeleton.get_node_or_null(body_path) as Bone2D if not body_path.is_empty() else null
	if body != null:
		pose.body_lean = rad_to_deg(body.rotation)
	return pose
