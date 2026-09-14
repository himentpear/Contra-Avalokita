@tool
class_name RotoBoneSemanticBoneMapper
extends RefCounted

const SEMANTIC_CANDIDATES := {
	"hips": ["Pelvis", "Hips"],
	"spine": ["Torso", "Spine", "SpineLower"],
	"chest": ["Torso", "Chest", "SpineUpper"],
	"spine_lower_helper": ["SpineLower"],
	"spine_upper_helper": ["SpineUpper"],
	"head": ["Head"],
	"upper_arm_l": ["UpperArmFront", "UpperArmL"],
	"lower_arm_l": ["ForearmFront", "LowerArmL"],
	"hand_l": ["HandFront", "HandL"],
	"upper_arm_r": ["UpperArmBack", "UpperArmR"],
	"lower_arm_r": ["ForearmBack", "LowerArmR"],
	"hand_r": ["HandBack", "HandR"],
	"upper_leg_l": ["ThighFront", "UpperLegL"],
	"lower_leg_l": ["ShinFront", "LowerLegL"],
	"foot_l": ["FootFront", "FootL"],
	"upper_leg_r": ["ThighBack", "UpperLegR"],
	"lower_leg_r": ["ShinBack", "LowerLegR"],
	"foot_r": ["FootBack", "FootR"],
}


func map_skeleton(skeleton: Skeleton2D) -> Dictionary:
	var bones_by_name := _collect_bones(skeleton)
	var mapping := {}
	for semantic_name in SEMANTIC_CANDIDATES:
		for candidate in SEMANTIC_CANDIDATES[semantic_name]:
			if bones_by_name.has(candidate):
				var bone: Bone2D = bones_by_name[candidate]
				mapping[semantic_name] = {
					"bone": String(bone.name),
					"path": String(skeleton.get_path_to(bone)),
				}
				break
	return mapping


func extract_hierarchy(skeleton: Skeleton2D) -> Array[Dictionary]:
	var roots: Array[Dictionary] = []
	for child in skeleton.get_children():
		if child is Bone2D:
			roots.append(_describe_bone(child as Bone2D, skeleton))
	return roots


func mapping_document(skeleton: Skeleton2D, source_scene: String) -> Dictionary:
	var instance_root: Node = skeleton
	while instance_root.get_parent() != null:
		instance_root = instance_root.get_parent()
	return {
		"schema_version": 1,
		"source_scene": source_scene,
		"skeleton_path": String(instance_root.get_path_to(skeleton)),
		"semantic_map": map_skeleton(skeleton),
		"hierarchy": extract_hierarchy(skeleton),
		"visual_connections": [{
			"from": "Pelvis/SpineLower/SpineUpper",
			"to": "Pelvis/Torso",
			"mode": "renderer_bridge",
		}],
	}


func _collect_bones(skeleton: Skeleton2D) -> Dictionary:
	var result := {}
	_collect_bones_recursive(skeleton, result)
	return result


func _collect_bones_recursive(node: Node, result: Dictionary) -> void:
	for child in node.get_children():
		if child is Bone2D:
			result[String(child.name)] = child
		_collect_bones_recursive(child, result)


func _describe_bone(bone: Bone2D, skeleton: Skeleton2D) -> Dictionary:
	var children: Array[Dictionary] = []
	for child in bone.get_children():
		if child is Bone2D:
			children.append(_describe_bone(child as Bone2D, skeleton))
	return {
		"name": String(bone.name),
		"path": String(skeleton.get_path_to(bone)),
		"children": children,
	}
