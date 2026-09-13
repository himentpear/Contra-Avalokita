class_name LevelRoot
extends Node2D

@export_group("Domain References")
@export var world: Node2D
@export var background_world: Node2D
@export var gameplay_world: Node2D
@export var foreground_world: Node2D
@export var lighting: Node2D
@export var environment_fx: Node2D
@export var runtime_fx: VFXRouter
@export var camera_rig: CameraFXController
@export var screen_fx: CanvasLayer
@export var ui: CanvasLayer
@export var environment_controller: LevelEnvironmentController
@export_group("")

@export var player: MudCharacter

func _ready() -> void:
	_resolve_domain_references()
	
	# Register with Game Session if active
	var game := get_node_or_null("/root/Game")
	if game and is_instance_valid(game.current_session) and game.current_session.has_method("set_player") and is_instance_valid(player):
		game.current_session.set_player(player)
	
	# Connect camera follow target to player
	if is_instance_valid(camera_rig) and is_instance_valid(player):
		camera_rig.follow_target = player

func _resolve_domain_references() -> void:
	if not world: world = get_node_or_null("World")
	if world:
		if not background_world: background_world = world.get_node_or_null("BackgroundWorld")
		if not gameplay_world: gameplay_world = world.get_node_or_null("GameplayWorld")
		if not foreground_world: foreground_world = world.get_node_or_null("ForegroundWorld")
		if not lighting: lighting = world.get_node_or_null("Lighting")
		if not environment_fx: environment_fx = world.get_node_or_null("EnvironmentFX")
	
	if not runtime_fx: runtime_fx = get_node_or_null("RuntimeFX") as VFXRouter
	if not camera_rig: camera_rig = get_node_or_null("CameraRig") as CameraFXController
	if not screen_fx: screen_fx = get_node_or_null("ScreenFX") as CanvasLayer
	if not ui: ui = get_node_or_null("UI") as CanvasLayer
	if not environment_controller: environment_controller = get_node_or_null("LevelEnvironmentController") as LevelEnvironmentController
	
	if not player and gameplay_world:
		player = gameplay_world.get_node_or_null("Player") as MudCharacter

## Centralized VFX Spawning API
func spawn_fx(effect: Node2D, channel: VFXRouter.Channel, world_position: Vector2, parent_to_target: Node2D = null) -> Node2D:
	if runtime_fx:
		return runtime_fx.spawn_fx(effect, channel, world_position, parent_to_target)
	add_child(effect)
	effect.global_position = world_position
	return effect

func spawn_light_flash(world_position: Vector2, color: Color = Color.WHITE, energy: float = 1.5, duration: float = 0.2) -> Node2D:
	var flash_scene: PackedScene = preload("res://scenes/fx/light_flash.tscn")
	var flash := flash_scene.instantiate() as DynamicLightFlash
	flash.color = color
	flash.energy = energy
	flash.initial_energy = energy
	flash.duration = duration
	return spawn_fx(flash, VFXRouter.Channel.DYNAMIC_LIGHT, world_position)

## Centralized Camera Shake API
func request_camera_shake(dir: Vector2, amp: float, duration: float = 0.08) -> void:
	if camera_rig:
		camera_rig.request_shake(dir, amp, duration)

func request_camera_trauma(amount: float) -> void:
	if camera_rig:
		camera_rig.request_trauma(amount)
