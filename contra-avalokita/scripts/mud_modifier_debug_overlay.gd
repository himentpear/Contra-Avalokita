class_name MudModifierDebugOverlay
extends Node2D
## One overlay per body renderer; all modifier diagnostics are drawn in one pass.

const SdfModifier = preload("res://scripts/sdf_modifier.gd")
var renderer: Node2D

func _draw() -> void:
	if not is_instance_valid(renderer) or not renderer.modifier_debug_draw:
		return
	var font := ThemeDB.fallback_font
	for i in renderer.resolved_modifier_count:
		var packed_a: Vector4 = renderer.modifier_a[i]
		var packed_b: Vector4 = renderer.modifier_b[i]
		var packed_meta: Vector4 = renderer.modifier_meta[i]
		var center_a := Vector2(packed_a.x, packed_a.y)
		var center_b := Vector2(packed_b.x, packed_b.y)
		var is_add := int(round(packed_meta.x)) == SdfModifier.Operation.ADD
		var is_capsule := int(round(packed_meta.y)) == SdfModifier.Shape.CAPSULE
		var color := Color(0.25, 1.0, 0.36, 0.92) if is_add else Color(1.0, 0.25, 0.24, 0.92)
		draw_arc(center_a, packed_a.z, 0.0, TAU, 28, color, 1.0)
		if is_capsule:
			draw_line(center_a, center_b, color, 1.0)
			draw_arc(center_b, packed_b.z, 0.0, TAU, 28, color, 1.0)
		var anchor_point: Vector2 = renderer.modifier_anchor_points[i]
		draw_circle(anchor_point, 1.5, Color.WHITE)
		var source: SdfModifier = renderer.packed_modifier_sources[i]
		if source:
			var operation_name := "ADD" if is_add else "SUBTRACT"
			var text := "%s  %s  %s  r=%.1f" % [source.id, source.anchor, operation_name, source.radius]
			draw_string(font, center_a + Vector2(4.0, -4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, color)
