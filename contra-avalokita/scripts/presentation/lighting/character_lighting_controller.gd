class_name CharacterLightingController
extends Node2D

const CharacterLightingProfileScript = preload("res://scripts/presentation/lighting/character_lighting_profile.gd")
const CharacterLightingBindingScript = preload("res://scripts/presentation/lighting/character_lighting_binding.gd")
const CharacterLightingContextScript = preload("res://scripts/presentation/lighting/character_lighting_context.gd")
const LightingRegistryScript = preload("res://scripts/presentation/lighting/lighting_registry.gd")

## Generic 2D presentation controller for character lighting and shadows.
## Completely decoupled from any gameplay mechanics, combat states, or concrete character classes.

@export var profile: CharacterLightingProfileScript
@export var binding: CharacterLightingBindingScript
@export var enabled: bool = true
@export var debug_draw: bool = false:
	set(v):
		debug_draw = v
		queue_redraw()

var context: CharacterLightingContextScript = CharacterLightingContextScript.new()

var current_direction := Vector2(0.0, -1.0)
var current_energy := 0.0
var current_color := Color.WHITE

var _last_active_light_count := 0
var _fallback_direction := Vector2(0.0, -1.0)

func _get_character_root() -> Node:
	var parent_node := get_parent()
	if parent_node != null and parent_node.name == "Visual" and parent_node.get_parent() != null:
		return parent_node.get_parent()
	return parent_node

func _ready() -> void:
	if not profile:
		profile = CharacterLightingProfileScript.new()
	if not binding:
		binding = CharacterLightingBindingScript.new()
	var char_root := _get_character_root()
	if is_instance_valid(char_root):
		binding.resolve(char_root)
	_apply_light_masks()

func setup(p_profile: CharacterLightingProfileScript, p_binding: CharacterLightingBindingScript, target_root: Node = null) -> void:
	profile = p_profile if p_profile else CharacterLightingProfileScript.new()
	binding = p_binding if p_binding else CharacterLightingBindingScript.new()
	var char_root := target_root if is_instance_valid(target_root) else _get_character_root()
	if is_instance_valid(char_root):
		binding.resolve(char_root)
	_apply_light_masks()

func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(profile) or not is_instance_valid(binding):
		return
	_gather_context()
	_evaluate_lighting(delta)
	_inject_shader_parameters()
	_update_ground_shadow()
	if debug_draw:
		queue_redraw()

func _gather_context() -> void:
	var char_root := _get_character_root()
	if char_root is Node2D:
		context.world_position = (char_root as Node2D).global_position
	else:
		context.world_position = global_position

	if char_root is CharacterBody2D:
		var body := char_root as CharacterBody2D
		context.velocity = body.velocity
		context.grounded = body.is_on_floor()

func _evaluate_lighting(delta: float) -> void:
	var candidate_lights := LightingRegistryScript.get_candidate_lights(get_tree(), context.world_position)
	_last_active_light_count = 0

	var weighted_dir := Vector2.ZERO
	var total_weight := 0.0
	var weighted_col := Color(0, 0, 0, 0)
	var max_radius := 600.0

	for light in candidate_lights:
		if not is_instance_valid(light) or not light.is_inside_tree() or not light.visible or not light.enabled:
			continue
		var to_light := light.global_position - context.world_position
		var dist := to_light.length()
		var light_rad := 64.0 * light.texture_scale
		if is_instance_valid(light.texture):
			light_rad = (light.texture.get_width() * 0.5) * light.texture_scale
		var eff_radius := maxf(light_rad, 150.0)
		if dist > eff_radius:
			continue

		var norm_d := clampf(dist / eff_radius, 0.0, 1.0)
		var atten := (1.0 - norm_d) * (1.0 - norm_d)
		var eff_energy := light.energy * atten
		if eff_energy <= 0.0001:
			continue

		var dir := to_light / maxf(dist, 0.001)
		weighted_dir += dir * eff_energy
		total_weight += eff_energy
		weighted_col += light.color * eff_energy
		_last_active_light_count += 1

	var target_dir := _fallback_direction
	var target_energy := 0.0
	var target_col := Color.WHITE

	if total_weight > 0.0001 and weighted_dir.length_squared() > 0.0001:
		var light_dir := weighted_dir.normalized()
		var blend := clampf(total_weight / 0.15, 0.0, 1.0)
		target_dir = _fallback_direction.lerp(light_dir, blend).normalized()
		var raw_col := weighted_col / total_weight
		target_col = Color.WHITE.lerp(raw_col, blend)
		target_energy = clampf(total_weight, 0.0, 2.5)
	else:
		target_dir = _fallback_direction
		target_energy = 0.0
		target_col = Color.WHITE

	var speed: float = profile.light_response_speed if profile else 12.0
	var factor := 1.0 - exp(-speed * delta)
	current_direction = current_direction.lerp(target_dir, factor)
	if current_direction.length_squared() > 0.0001:
		current_direction = current_direction.normalized()
	else:
		current_direction = _fallback_direction

	current_energy = lerpf(current_energy, target_energy, factor)
	current_color = current_color.lerp(target_col, factor)

	context.key_direction = current_direction
	context.key_energy = current_energy
	context.key_color = current_color

func _inject_shader_parameters() -> void:
	var shadow_c: Color = profile.shadow_color if profile else Color(0.40, 0.45, 0.52, 1.0)
	var mid_c: Color = profile.mid_color if profile else Color.WHITE
	var key_c: Color = profile.key_color if profile else Color.WHITE
	var min_amb: float = profile.minimum_ambient if profile else 0.55
	var mid_lvl: float = profile.mid_level if profile else 0.82
	var key_lvl: float = profile.key_level if profile else 1.10
	var rim_str: float = profile.rim_strength if profile else 0.35
	var rim_w: float = profile.rim_width if profile else 0.12
	var wpn_str: float = profile.weapon_highlight_strength if profile else 1.4
	var metal_w: float = profile.metal_highlight_width if profile else 0.08

	for body_item in binding.body_renderers:
		if is_instance_valid(body_item):
			var local_dir := _to_item_local_dir(body_item, current_direction)
			_write_material_params(body_item, {
				"light_direction": local_dir,
				"light_color": current_color,
				"light_energy": current_energy,
				"minimum_ambient": min_amb,
				"mid_level": mid_lvl,
				"key_level": key_lvl,
				"shadow_color": shadow_c,
				"mid_color": mid_c,
				"key_color": key_c,
				"rim_strength": rim_str,
				"rim_width": rim_w,
				"weapon_highlight_strength": 0.0,
				"hit_flash": context.hit_flash,
				"status_tint": context.status_tint,
				"dissolve_amount": context.dissolve_amount,
			})

	for wpn_item in binding.weapon_renderers:
		if is_instance_valid(wpn_item) and wpn_item.material is ShaderMaterial:
			var local_dir := _to_item_local_dir(wpn_item, current_direction)
			_write_material_params(wpn_item, {
				"light_direction": local_dir,
				"light_color": current_color,
				"light_energy": current_energy,
				"minimum_ambient": min_amb,
				"mid_level": mid_lvl,
				"key_level": key_lvl,
				"shadow_color": shadow_c,
				"mid_color": mid_c,
				"key_color": key_c,
				"rim_strength": rim_str,
				"rim_width": rim_w,
				"weapon_highlight_strength": wpn_str,
				"metal_highlight_width": metal_w,
				"hit_flash": context.hit_flash,
				"status_tint": context.status_tint,
				"dissolve_amount": context.dissolve_amount,
			})

	for em_item in binding.emissive_renderers:
		if is_instance_valid(em_item):
			_write_material_params(em_item, {
				"emissive_dissolve": context.emissive_dissolve,
				"status_tint": context.status_tint,
			})

func _to_item_local_dir(item: CanvasItem, world_dir: Vector2) -> Vector2:
	if not is_instance_valid(item) or not item.is_inside_tree():
		return world_dir
	var xform: Transform2D = item.global_transform
	var local_v: Vector2 = xform.affine_inverse().basis_xform(world_dir)
	if local_v.length_squared() > 0.0001:
		return local_v.normalized()
	return world_dir

func _write_material_params(item: CanvasItem, params: Dictionary) -> void:
	var mat := item.material as ShaderMaterial
	if is_instance_valid(mat):
		for k: String in params:
			mat.set_shader_parameter(k, params[k])
	# If the item has a dedicated shader_material (like MudBodyRenderer)
	if "shader_material" in item:
		var sm := item.get("shader_material") as ShaderMaterial
		if is_instance_valid(sm):
			for k: String in params:
				sm.set_shader_parameter(k, params[k])
	# If the item has child layers (like MudBodyRenderer depth materials)
	if "depth_materials" in item:
		var d_mats: Array = item.get("depth_materials") as Array
		if d_mats != null:
			for d_mat in d_mats:
				var sm := d_mat as ShaderMaterial
				if is_instance_valid(sm):
					for k: String in params:
						sm.set_shader_parameter(k, params[k])
	# Bound weapon sprites are visited directly. MudBodyRenderer exposes its own
	# depth materials above, so recursing into children only writes them twice.

func _apply_light_masks() -> void:
	var actor_mask: int = profile.actor_light_mask if profile else 8
	var emissive_mask: int = profile.emissive_light_mask if profile else 32

	for item in binding.body_renderers:
		if is_instance_valid(item):
			item.light_mask = actor_mask
			for child in item.get_children():
				if child is CanvasItem:
					(child as CanvasItem).light_mask = actor_mask

	for item in binding.weapon_renderers:
		if is_instance_valid(item):
			item.light_mask = actor_mask
			for child in item.get_children():
				if child is CanvasItem:
					(child as CanvasItem).light_mask = actor_mask

	for item in binding.emissive_renderers:
		if is_instance_valid(item):
			item.light_mask = emissive_mask
			for child in item.get_children():
				if child is CanvasItem:
					(child as CanvasItem).light_mask = emissive_mask

	for fx in [binding.local_fx_behind, binding.local_fx_body, binding.local_fx_front]:
		if is_instance_valid(fx):
			fx.light_mask = actor_mask
			for child in fx.get_children():
				if child is CanvasItem:
					(child as CanvasItem).light_mask = actor_mask

func _update_ground_shadow() -> void:
	if not is_instance_valid(binding.ground_shadow):
		return
	var shadow := binding.ground_shadow
	var shadow_enabled: bool = profile.ground_shadow_enabled if profile else false
	if not shadow_enabled:
		shadow.visible = false
		return
	shadow.visible = true
	var base_scale: Vector2 = profile.ground_shadow_base_scale if profile else Vector2(1.0, 0.28)
	var base_alpha: float = profile.ground_shadow_base_alpha if profile else 0.55
	var max_dist: float = profile.ground_shadow_max_distance if profile else 120.0

	var dist: float = context.ground_distance
	if not context.grounded and dist <= 0.0:
		# Estimate from vertical speed/position if raycast not present
		dist = clampf(absf(context.velocity.y) * 0.08, 0.0, max_dist)

	var p := clampf(dist / max_dist, 0.0, 1.0)
	var scale_factor := lerpf(1.0, 0.40, p)
	shadow.scale = Vector2(base_scale.x * scale_factor, base_scale.y * scale_factor)
	var target_alpha := lerpf(base_alpha, 0.12, p)
	if context.dissolve_amount > 0.5:
		target_alpha = lerpf(target_alpha, 0.0, (context.dissolve_amount - 0.5) * 2.0)
	shadow.modulate.a = target_alpha

func _draw() -> void:
	if not debug_draw:
		return
	# Debug visualization: directional pointer above character head
	var origin := Vector2(0, -60)
	draw_circle(origin, 3.0, Color.YELLOW)
	draw_line(origin, origin + current_direction * 24.0, Color.CYAN, 2.0)
	draw_arc(origin, 24.0, 0, TAU, 16, Color(1, 1, 1, 0.2), 1.0)
