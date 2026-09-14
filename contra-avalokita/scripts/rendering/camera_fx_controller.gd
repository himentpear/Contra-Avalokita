class_name CameraFXController
extends Node2D

@export var camera: Camera2D
@export var follow_target: Node2D
@export var follow_speed := 10.0
@export var max_shake_offset := Vector2(24.0, 16.0)
@export var trauma_decay := 1.8
@export var max_roll_degrees := 1.5
@export var lock_y := false
@export var fixed_y := 0.0

var trauma := 0.0
var shake_dir := Vector2.RIGHT
var shake_amp := 0.0
var shake_timer := 0.0
var shake_duration := 0.0

var zoom_kick := 1.0
var zoom_kick_timer := 0.0
var zoom_kick_duration := 0.0
var base_zoom := Vector2.ONE

func _ready() -> void:
	if not camera:
		camera = get_node_or_null("../Camera2D") as Camera2D
		if not camera:
			camera = get_node_or_null("Camera2D") as Camera2D
	if camera:
		base_zoom = camera.zoom

func request_shake(dir: Vector2, amp: float, duration: float = 0.08) -> void:
	shake_dir = dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	shake_amp = amp
	shake_duration = maxf(duration, 0.001)
	shake_timer = shake_duration

func request_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func request_zoom_kick(multiplier: float, duration: float = 0.12) -> void:
	zoom_kick = multiplier
	zoom_kick_duration = maxf(duration, 0.001)
	zoom_kick_timer = zoom_kick_duration

func _process(delta: float) -> void:
	if not is_instance_valid(camera): return
	
	# 1. Target Tracking
	if is_instance_valid(follow_target):
		var target_pos := follow_target.global_position
		camera.global_position.x = lerpf(camera.global_position.x, target_pos.x, 1.0 - exp(-follow_speed * delta))
		if lock_y:
			camera.global_position.y = fixed_y
		else:
			camera.global_position.y = lerpf(camera.global_position.y, clampf(target_pos.y - 20.0, camera.limit_top + 180.0, camera.limit_bottom - 180.0), 1.0 - exp(-follow_speed * 0.5 * delta))
	
	# 2. Directed Shake calculation
	var current_offset := Vector2.ZERO
	if shake_timer > 0.0:
		shake_timer = maxf(0.0, shake_timer - delta)
		var p: float = shake_timer / shake_duration
		var osc: float = cos((shake_duration - shake_timer) * 60.0) * shake_amp * p
		current_offset += shake_dir * osc
	
	# 3. Trauma Shake calculation
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		var shake_p := trauma * trauma
		var noise_x := (randf() * 2.0 - 1.0) * max_shake_offset.x * shake_p
		var noise_y := (randf() * 2.0 - 1.0) * max_shake_offset.y * shake_p
		current_offset += Vector2(noise_x, noise_y)
		camera.rotation_degrees = (randf() * 2.0 - 1.0) * max_roll_degrees * shake_p
	else:
		camera.rotation_degrees = 0.0
	
	camera.offset = current_offset
	
	# 4. Zoom Kick
	if zoom_kick_timer > 0.0:
		zoom_kick_timer = maxf(0.0, zoom_kick_timer - delta)
		var zp := zoom_kick_timer / zoom_kick_duration
		camera.zoom = base_zoom * lerpf(1.0, zoom_kick, zp)
	else:
		camera.zoom = base_zoom
