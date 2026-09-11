class_name EquipmentManager
extends Node2D
@export var head_piece: PackedScene = preload("res://scenes/equipment/helmet.tscn")
@export var forearm_piece: PackedScene = preload("res://scenes/equipment/bracer.tscn")
var slots: Dictionary = {}
var equipped := true

func _ready() -> void:
	for id in [&"HeadSlot", &"ForearmSlot"]:
		var marker := Marker2D.new()
		marker.name = id
		add_child(marker)
		slots[id] = marker
	equip(&"HeadSlot", head_piece)
	equip(&"ForearmSlot", forearm_piece)

func equip(slot: StringName, scene: PackedScene) -> void:
	assert(slots.has(slot))
	for child in slots[slot].get_children():
		slots[slot].remove_child(child)
		child.queue_free()
	if scene: slots[slot].add_child(scene.instantiate())

func toggle() -> void:
	equipped = not equipped
	visible = equipped

func sync_bones(head_bone: Bone2D, forearm_bone: Bone2D, hand_bone: Bone2D) -> void:
	if not slots.has(&"HeadSlot"): return
	if is_instance_valid(head_bone):
		var head_pos := to_local(head_bone.global_position)
		var head_up := (to_local(head_bone.to_global(Vector2.UP)) - head_pos).normalized()
		var head_angle := head_up.angle() + PI / 2.0
		slots[&"HeadSlot"].position = head_pos + head_up * 6.0
		slots[&"HeadSlot"].rotation = head_angle
	if is_instance_valid(forearm_bone) and is_instance_valid(hand_bone):
		var elbow := to_local(forearm_bone.global_position)
		var hand := to_local(hand_bone.global_position)
		slots[&"ForearmSlot"].position = elbow.lerp(hand, 0.65)
		slots[&"ForearmSlot"].rotation = (hand - elbow).angle() - PI / 2.0

func sync(rig: MudRig) -> void:
	if not slots.has(&"HeadSlot") or rig == null: return
	slots[&"HeadSlot"].position = rig.point(&"Head") + Vector2(0, -6)
	var elbow := rig.point(&"ArmFrontJoint")
	var hand := rig.point(&"ArmFrontEnd")
	slots[&"ForearmSlot"].position = elbow.lerp(hand, 0.65)
	slots[&"ForearmSlot"].rotation = (hand - elbow).angle() - PI / 2

func sync_death(death_progress: float, embed: bool) -> void:
	if not slots.has(&"HeadSlot"): return
	if death_progress <= 0.0:
		visible = true
		if slots.has(&"ForearmSlot"):
			slots[&"ForearmSlot"].visible = true
		return
	if not embed:
		visible = death_progress < 0.35
		return
	visible = true
	if death_progress > 0.15:
		var p := clampf((death_progress - 0.15) / 0.65, 0.0, 1.0)
		p = ease(p, 0.5)
		if slots.has(&"HeadSlot"):
			slots[&"HeadSlot"].position.y = lerpf(slots[&"HeadSlot"].position.y, -3.0, p)
			slots[&"HeadSlot"].rotation = lerpf(slots[&"HeadSlot"].rotation, 0.28, p)
		if slots.has(&"ForearmSlot"):
			slots[&"ForearmSlot"].position.y = lerpf(slots[&"ForearmSlot"].position.y, 2.0, p)
			slots[&"ForearmSlot"].visible = death_progress < 0.60

