class_name SdfModifier
extends Resource
## One cached SDF operation bound to the renderer's animated anatomy anchors.

enum Operation {
	ADD,
	SUBTRACT,
}

enum Shape {
	CIRCLE,
	CAPSULE,
}

@export var id: StringName = &"Modifier"
@export var operation: Operation = Operation.ADD
@export var shape: Shape = Shape.CIRCLE
@export var anchor: StringName = &"Torso"
@export var anchor_b: StringName = &""
@export var local_offset := Vector2.ZERO
@export var end_local_offset := Vector2.ZERO
@export_range(0.1, 32.0, 0.1) var radius := 4.0
@export_range(0.1, 32.0, 0.1) var radius_end := 4.0
@export_range(0.0, 64.0, 0.1) var length := 8.0
@export_range(-PI, PI, 0.01) var rotation := 0.0
@export_range(0.0, 8.0, 0.05) var softness := 1.0
@export_range(-1.0, 1.0, 1.0) var depth := 0.0
@export var enabled := true
