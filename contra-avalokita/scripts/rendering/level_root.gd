class_name LevelRoot
extends Node2D

## Global 2D Scene Architecture Root
##
## ARCHITECTURAL SAFETY RULES:
## 1. DirectionalLight2D Safety Rule:
##    DirectionalLight2D must NOT be used when strict domain isolation depends only on
##    range_item_cull_mask. Background/Game/Foreground isolation must use appropriately
##    scoped PointLight2D nodes unless a deliberate global directional light is intended
##    and audited for layer/z ranges.
##
## 2. Parallax Vertical Policy:
##    X axis uses depth parallax (0.12x Far .. 1.22x Occluders).
##    Y axis currently remains 1.0 across all parallax layers to maintain stable platform/horizon
##    alignment during vertical camera motion. If a future vertical shaft/level requires vertical-depth
##    parallax, it must be explicitly overridden per level.
##
## 3. LightMask & CanvasModulate Policy:
##    CanvasItem.light_mask controls interaction with Light2D (via range_item_cull_mask).
##    It does NOT bypass CanvasModulate. Bit 6 (32) is designated for EMISSIVE_VISUAL / SPECIAL_FX
##    artwork and dedicated lighting interactions, not CanvasModulate exclusion.

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

enum RenderPolicy {
	PIXEL_STRICT,
	SUBPIXEL_WORLD
}

@export var player: MudCharacter

func _ready() -> void:
	_resolve_domain_references()
	apply_render_policies()
	
	# Register with Game Session if active
	var game := get_node_or_null("/root/Game")
	if game and is_instance_valid(game.current_session) and game.current_session.has_method("set_player") and is_instance_valid(player):
		game.current_session.set_player(player)
	
	# Connect camera follow target to player
	if is_instance_valid(camera_rig) and is_instance_valid(player):
		camera_rig.follow_target = player

func apply_render_policies() -> void:
	# PIXEL_STRICT: GameplayWorld preserves crisp pixel-art texels without bilinear blurring
	if is_instance_valid(gameplay_world):
		gameplay_world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# SUBPIXEL_WORLD: FarBackground and distant layers use LINEAR / LINEAR_WITH_MIPMAPS
	# for continuous subpixel interpolation during slow parallax motion
	if is_instance_valid(background_world):
		var far_bg: CanvasItem = background_world.get_node_or_null("FarBackground") as CanvasItem
		if far_bg:
			far_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		
		var dist_struct: CanvasItem = background_world.get_node_or_null("DistantStructures") as CanvasItem
		if dist_struct:
			dist_struct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		
		var mid_bg: CanvasItem = background_world.get_node_or_null("MidBackground") as CanvasItem
		if mid_bg:
			mid_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		
		var near_bg: CanvasItem = background_world.get_node_or_null("NearBackground") as CanvasItem
		if near_bg:
			near_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Environment FX: particles and volumetric atmospheric haze use LINEAR for continuous motion
	if is_instance_valid(environment_fx):
		for channel in ["FarFX", "MidFX", "GameplayWorldFX", "NearFX"]:
			var fx_node: CanvasItem = environment_fx.get_node_or_null(channel) as CanvasItem
			if fx_node:
				fx_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Foreground world
	if is_instance_valid(foreground_world):
		var near_fg: CanvasItem = foreground_world.get_node_or_null("NearForeground") as CanvasItem
		if near_fg:
			near_fg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var front_occ: CanvasItem = foreground_world.get_node_or_null("FrontOccluders") as CanvasItem
		if front_occ:
			front_occ.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# UI: Pixel-strict UI rendering
	if is_instance_valid(ui):
		for child in ui.get_children():
			if child is CanvasItem:
				(child as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

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

## Spawns a character-attached effect that rigidly inherits the actor's transform
func spawn_character_fx(character: Node2D, effect: Node2D, local_channel: VFXRouter.LocalChannel, local_offset: Vector2 = Vector2.ZERO) -> Node2D:
	if runtime_fx:
		return runtime_fx.spawn_character_fx(character, effect, local_channel, local_offset)
	if character:
		character.add_child(effect)
		effect.position = local_offset
		return effect
	add_child(effect)
	return effect

## Spawns a world-space runtime effect that remains independent of actors
func spawn_world_fx(effect: Node2D, world_channel: VFXRouter.WorldChannel, global_pos: Vector2) -> Node2D:
	if runtime_fx:
		return runtime_fx.spawn_world_fx(effect, world_channel, global_pos)
	add_child(effect)
	effect.global_position = global_pos
	return effect

## Centralized VFX Spawning API (legacy / unified)
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
	if runtime_fx:
		return runtime_fx.spawn_world_fx(flash, VFXRouter.WorldChannel.DYNAMIC_LIGHT, world_position)
	return spawn_fx(flash, VFXRouter.Channel.DYNAMIC_LIGHT, world_position)

## Centralized Camera Shake API
func request_camera_shake(dir: Vector2, amp: float, duration: float = 0.08) -> void:
	if camera_rig:
		camera_rig.request_shake(dir, amp, duration)

func request_camera_trauma(amount: float) -> void:
	if camera_rig:
		camera_rig.request_trauma(amount)
