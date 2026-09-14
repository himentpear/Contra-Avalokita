@tool
class_name RotoBonePoseContractGuard
extends Node

signal contract_corrected(bone_names: PackedStringArray)

@export_node_path("Skeleton2D") var skeleton_path := NodePath("../MudCharacterInstance/Visual/PoseRoot/Skeleton2D")
@export var rotation_only := true

var _contract: Dictionary = {}


func _ready() -> void:
	call_deferred("capture_contract")
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	enforce_contract()


func capture_contract() -> bool:
	var skeleton := get_node_or_null(skeleton_path) as Skeleton2D
	if skeleton == null:
		return false
	_contract.clear()
	for bone in _collect_bones(skeleton):
		_contract[String(bone.name)] = {
			"parent_path": String(skeleton.get_path_to(bone.get_parent())),
			"position": bone.position,
			"scale": bone.scale,
			"skew": bone.skew,
			"rest": bone.rest,
			"length": bone.length,
			"bone_angle": bone.bone_angle,
			"auto_calculate": bone.get_autocalculate_length_and_angle(),
		}
	return true


func enforce_contract() -> PackedStringArray:
	var corrected := PackedStringArray()
	if not rotation_only:
		return corrected
	var skeleton := get_node_or_null(skeleton_path) as Skeleton2D
	if skeleton == null:
		return corrected
	if _contract.is_empty():
		capture_contract()
		return corrected
	for bone_name in _contract:
		var bone := _find_bone(skeleton, bone_name)
		if bone == null:
			continue
		var state: Dictionary = _contract[bone_name]
		var rotation_value := bone.rotation
		var changed := false
		var expected_parent := skeleton.get_node_or_null(NodePath(state.parent_path))
		if expected_parent != null and bone.get_parent() != expected_parent:
			bone.reparent(expected_parent, false)
			changed = true
		if bone.position != state.position:
			bone.position = state.position
			changed = true
		if bone.scale != state.scale:
			bone.scale = state.scale
			changed = true
		if not is_equal_approx(bone.skew, float(state.skew)):
			bone.skew = state.skew
			changed = true
		if bone.rest != state.rest:
			bone.rest = state.rest
			changed = true
		if not is_equal_approx(bone.length, float(state.length)):
			bone.length = state.length
			changed = true
		if not is_equal_approx(bone.bone_angle, float(state.bone_angle)):
			bone.bone_angle = state.bone_angle
			changed = true
		if bone.get_autocalculate_length_and_angle() != bool(state.auto_calculate):
			bone.set_autocalculate_length_and_angle(state.auto_calculate)
			changed = true
		bone.rotation = rotation_value
		if changed:
			corrected.append(bone_name)
	if not corrected.is_empty():
		contract_corrected.emit(corrected)
	return corrected


func _find_bone(skeleton: Skeleton2D, bone_name: String) -> Bone2D:
	for bone in _collect_bones(skeleton):
		if bone.name == bone_name:
			return bone
	return null


func _collect_bones(skeleton: Skeleton2D) -> Array[Bone2D]:
	var bones: Array[Bone2D] = []
	_collect_recursive(skeleton, bones)
	return bones


func _collect_recursive(node: Node, bones: Array[Bone2D]) -> void:
	for child in node.get_children():
		if child is Bone2D:
			bones.append(child as Bone2D)
		_collect_recursive(child, bones)
