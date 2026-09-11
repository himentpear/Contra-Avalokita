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

func sync(rig: MudRig) -> void:
	slots[&"HeadSlot"].position = rig.point(&"Head") + Vector2(0, -6)
	var elbow := rig.point(&"ArmFrontJoint")
	var hand := rig.point(&"ArmFrontEnd")
	slots[&"ForearmSlot"].position = elbow.lerp(hand, 0.65)
	slots[&"ForearmSlot"].rotation = (hand - elbow).angle() - PI / 2

