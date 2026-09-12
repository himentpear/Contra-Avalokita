class_name MudPixelAscension
extends Node2D
## Pixel particles peeled from the same capsule data used by the body SDF.

@export_range(8, 96) var particle_count := 42
@export_range(0.0, 0.8) var emission_span := 0.32
@export var rise_speed := Vector2(8.0, 54.0)
@export var upward_acceleration := 18.0
@export var lifetime_range := Vector2(0.75, 1.35)

class AscendingPixel:
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var age := 0.0
	var lifetime := 1.0
	var phase := 0.0
	var drift := 0.0
	var size := 1.0
	var color := Color.WHITE

var particles: Array[AscendingPixel] = []
var active := false

func begin_from_sdf(renderer: MudBodyRenderer, base_color: Color, count := -1) -> void:
	reset()
	if not renderer or renderer.segment_cursor <= 0:
		return

	var amount := particle_count if count < 0 else count
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5DFD347
	var palette := [base_color.darkened(0.22), base_color, base_color.lightened(0.22)]
	var source_count := mini(renderer.segment_cursor, renderer.segments.size())
	for i in amount:
		var source := renderer.segments[rng.randi_range(0, source_count - 1)]
		var along := rng.randf()
		var axis := source.end_position - source.start_position
		var normal := Vector2(-axis.y, axis.x).normalized()
		if normal.length_squared() < 0.001:
			normal = Vector2.RIGHT
		var radius := lerpf(source.radius_start, source.radius_end, along)

		var pixel := AscendingPixel.new()
		pixel.position = source.start_position.lerp(source.end_position, along)
		pixel.position += normal * rng.randf_range(-radius * 0.72, radius * 0.72)
		pixel.velocity = Vector2(
			rng.randf_range(-rise_speed.x, rise_speed.x),
			-rng.randf_range(rise_speed.y * 0.72, rise_speed.y * 1.18)
		)
		pixel.age = -rng.randf_range(0.0, emission_span)
		pixel.lifetime = rng.randf_range(lifetime_range.x, lifetime_range.y)
		pixel.phase = rng.randf_range(0.0, TAU)
		pixel.drift = rng.randf_range(2.0, 7.0)
		var size_roll := rng.randf()
		pixel.size = 1.0 if size_roll < 0.42 else (2.0 if size_roll < 0.90 else 3.0)
		pixel.color = palette[rng.randi_range(0, palette.size() - 1)]
		particles.append(pixel)

	active = not particles.is_empty()
	set_process(active)
	queue_redraw()

func reset() -> void:
	particles.clear()
	active = false
	set_process(false)
	queue_redraw()

func visible_particle_count() -> int:
	var result := 0
	for pixel in particles:
		if pixel.age >= 0.0 and pixel.age < pixel.lifetime:
			result += 1
	return result

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if not active:
		return
	var any_alive := false
	for pixel in particles:
		pixel.age += delta
		if pixel.age < 0.0:
			any_alive = true
			continue
		if pixel.age >= pixel.lifetime:
			continue
		any_alive = true
		pixel.velocity.y -= upward_acceleration * delta
		pixel.position += pixel.velocity * delta
		pixel.position.x += sin(pixel.age * 8.0 + pixel.phase) * pixel.drift * delta
	active = any_alive
	set_process(active)
	queue_redraw()

func _draw() -> void:
	for pixel in particles:
		if pixel.age < 0.0 or pixel.age >= pixel.lifetime:
			continue
		var fade := clampf((pixel.lifetime - pixel.age) / 0.24, 0.0, 1.0)
		var color := pixel.color
		color.a *= fade
		var snapped := pixel.position.round()
		draw_rect(Rect2(snapped - Vector2.ONE * pixel.size * 0.5, Vector2.ONE * pixel.size), color)
