class_name MudBodyRenderer
extends Node2D
const MAX_SEGMENTS := 40
@export var mud_color := Color("737f45")
@export_range(0.1, 4.0) var fusion_softness := 1.8
@export var render_bounds := Rect2(-80, -104, 160, 128)
@export_range(0.5, 2.0) var edge_width := 1.0
@export_range(0.0, 0.05) var surface_noise := 0.025
var shader_material: ShaderMaterial
var endpoints := PackedVector4Array()
var properties := PackedVector4Array()

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

func sync(rig: MudRig) -> void:
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

