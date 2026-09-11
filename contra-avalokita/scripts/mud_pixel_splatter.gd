class_name MudPixelSplatter
extends Node2D
## Authentic pixel-art mud splatter: integer-snapped square droplets with floor collision.

@export var default_mud_color := Color("737f45")
@export var gravity := 420.0
@export var ground_y := 0.0

class Droplet:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var color := Color.WHITE
	var size := 2.0
	var grounded := false
	var lifetime := 0.0
	var max_lifetime := 1.2

var droplets: Array[Droplet] = []
var active := false

func burst(origin: Vector2, count: int, base_color: Color = default_mud_color, spread_radius := 14.0) -> void:
	droplets.clear()
	active = true
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	var dark_color := base_color.darkened(0.25)
	var light_color := base_color.lightened(0.20)
	
	for i in count:
		var d := Droplet.new()
		# Slight horizontal offset around impact zone
		d.pos = origin + Vector2(rng.randf_range(-spread_radius, spread_radius), rng.randf_range(-4, 0))
		# Arc upward and outward
		var angle := rng.randf_range(-PI * 0.85, -PI * 0.15)
		var speed := rng.randf_range(35.0, 95.0)
		d.vel = Vector2(cos(angle), sin(angle)) * speed
		# Discrete pixel sizes: mostly 2x2, some 1x1, rare 3x2 chunk
		var size_rand := rng.randf()
		d.size = 1.0 if size_rand < 0.35 else (2.0 if size_rand < 0.85 else 3.0)
		# Palette color selection (dark edge, mid tone, specular shine)
		if rng.randf() < 0.20:
			d.color = light_color # Wet highlight droplet
		elif rng.randf() < 0.55:
			d.color = base_color
		else:
			d.color = dark_color
		d.max_lifetime = rng.randf_range(0.9, 1.4)
		droplets.append(d)
	queue_redraw()

func _process(delta: float) -> void:
	if not active or droplets.is_empty(): return
	var any_alive := false
	for d in droplets:
		d.lifetime += delta
		if not d.grounded:
			d.vel.y += gravity * delta
			d.pos += d.vel * delta
			if d.pos.y >= ground_y:
				d.pos.y = ground_y
				d.vel = Vector2.ZERO
				d.grounded = true
		if d.lifetime < d.max_lifetime:
			any_alive = true
	if not any_alive:
		active = false
	queue_redraw()

func _draw() -> void:
	if droplets.is_empty(): return
	for d in droplets:
		if d.lifetime >= d.max_lifetime: continue
		# Snap to integer coordinates for pixel art crispness
		var px := roundf(d.pos.x)
		var py := roundf(d.pos.y)
		var sz := d.size
		if d.grounded:
			# Splat on the floor: flattens horizontally
			draw_rect(Rect2(px - sz * 0.5, py - 1.0, sz + 1.0, 1.0), d.color)
		else:
			draw_rect(Rect2(px, py, sz, sz), d.color)
