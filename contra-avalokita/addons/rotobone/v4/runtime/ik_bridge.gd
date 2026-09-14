@tool
class_name RotoIKBridge
extends RefCounted

var solver := RotoPoseSolver.new()


func bind(skeleton: Skeleton2D, semantic_map: Dictionary) -> void:
	solver.configure(skeleton, semantic_map)


func solve(pose: RotoPose) -> bool:
	return solver.apply_pose(pose)
