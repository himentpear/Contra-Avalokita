class_name SDFBodyComponent
extends Node

const SdfModifier = preload("res://gameplay/character/sdf/sdf_modifier.gd")
const SdfMorphProfile = preload("res://gameplay/character/sdf/sdf_morph_profile.gd")

var character: CharacterBody2D
var body_renderer: MudBodyRenderer

var impact_depth: float:
	get: return body_renderer.impact_depth if body_renderer else 0.0
	set(v): if body_renderer: body_renderer.impact_depth = v

var impact_bulge_height: float:
	get: return body_renderer.impact_bulge_height if body_renderer else 0.0
	set(v): if body_renderer: body_renderer.impact_bulge_height = v

var impact_radius: float:
	get: return body_renderer.impact_radius if body_renderer else 0.0
	set(v): if body_renderer: body_renderer.impact_radius = v

var impact_bulge_radius: float:
	get: return body_renderer.impact_bulge_radius if body_renderer else 0.0
	set(v): if body_renderer: body_renderer.impact_bulge_radius = v

var impact_center: Vector2:
	get: return body_renderer.impact_center if body_renderer else Vector2.ZERO
	set(v): if body_renderer: body_renderer.impact_center = v

var impact_bulge_center: Vector2:
	get: return body_renderer.impact_bulge_center if body_renderer else Vector2.ZERO
	set(v): if body_renderer: body_renderer.impact_bulge_center = v

var impact_ripple_phase: float:
	get: return body_renderer.impact_ripple_phase if body_renderer else 0.0
	set(v): if body_renderer: body_renderer.impact_ripple_phase = v

var facing_depth: float:
	get: return body_renderer.facing_depth if body_renderer else 1.0
	set(v): if body_renderer: body_renderer.facing_depth = v

var weapon_arm_depth: float:
	get: return body_renderer.weapon_arm_depth if body_renderer else 1.0
	set(v): if body_renderer: body_renderer.weapon_arm_depth = v

var offhand_arm_depth: float:
	get: return body_renderer.offhand_arm_depth if body_renderer else -1.0
	set(v): if body_renderer: body_renderer.offhand_arm_depth = v

var modifier_debug_draw: bool:
	get: return body_renderer.modifier_debug_draw if body_renderer else false
	set(v): if body_renderer: body_renderer.modifier_debug_draw = v

var compressions: Dictionary:
	get: return body_renderer.compressions if body_renderer else {}

var angles: Dictionary:
	get: return body_renderer.angles if body_renderer else {}

var segments: Array[MudSegment]:
	get: return body_renderer.segments if body_renderer else []

func setup(p_character: CharacterBody2D, p_renderer: MudBodyRenderer = null) -> void:
	character = p_character
	if p_renderer:
		body_renderer = p_renderer
	elif character:
		body_renderer = character.get_node_or_null("Visual/MudBodyRenderer") as MudBodyRenderer

func point(id: StringName) -> Vector2:
	return body_renderer.point(id) if body_renderer else Vector2.ZERO

func apply_impact(impact_local: Vector2, direction: Vector2, facing: float, intensity: float) -> void:
	if not body_renderer: return
	body_renderer.impact_center = impact_local
	body_renderer.impact_radius = 8.5
	body_renderer.impact_depth = 3.2 * intensity
	var opp_offset := direction.x * facing * 12.0
	body_renderer.impact_bulge_center = impact_local + Vector2(opp_offset, 0.0)
	body_renderer.impact_bulge_radius = 7.5
	body_renderer.impact_bulge_height = 1.8 * intensity

func update_impact_deformation(delta: float, has_reaction: bool, reaction_time: float, reaction_duration: float, reaction_intensity: float, reaction_impact_local: Vector2, reaction_direction: Vector2, facing: float) -> void:
	if not body_renderer: return
	if has_reaction:
		body_renderer.impact_center = reaction_impact_local
		body_renderer.impact_radius = 8.5
		var opp_offset := reaction_direction.x * facing * 12.0
		body_renderer.impact_bulge_center = reaction_impact_local + Vector2(opp_offset, 0.0)
		body_renderer.impact_bulge_radius = 7.5
		var progress: float = clampf(reaction_time / maxf(reaction_duration, 0.001), 0.0, 1.0)
		body_renderer.impact_depth = lerpf(3.2 * reaction_intensity, 0.0, progress)
		body_renderer.impact_bulge_height = lerpf(1.8 * reaction_intensity, 0.0, progress)
		body_renderer.impact_ripple_phase += delta * 4.5
	else:
		body_renderer.impact_depth = move_toward(body_renderer.impact_depth, 0.0, delta * 20.0)
		body_renderer.impact_bulge_height = move_toward(body_renderer.impact_bulge_height, 0.0, delta * 20.0)

func reset_impact() -> void:
	if not body_renderer: return
	body_renderer.impact_depth = 0.0
	body_renderer.impact_bulge_height = 0.0

func set_hit_flash(amount: float, color: Color = Color.WHITE) -> void:
	if body_renderer:
		body_renderer.set_hit_flash(amount, color)

func sync_skeleton(skeleton: Skeleton2D, delta: float) -> void:
	if body_renderer and skeleton:
		body_renderer.sync_skeleton(skeleton, delta)

func sync_death(death_controller: MudDeathController, delta: float, skeleton: Skeleton2D) -> void:
	if not body_renderer or not death_controller: return
	body_renderer.death_progress = death_controller.death_progress
	body_renderer.death_dissolve = death_controller.dissolve_progress()
	body_renderer.puddle_spread_ratio = death_controller.puddle_spread_ratio
	body_renderer.limb_retraction_strength = death_controller.limb_retraction_strength
	body_renderer.torso_squash_ratio = death_controller.torso_squash_ratio
	body_renderer.sync_skeleton(skeleton, delta)

func reset_death() -> void:
	if not body_renderer: return
	body_renderer.death_progress = 0.0
	body_renderer.death_dissolve = 0.0

func apply_morph_profile(profile: SdfMorphProfile) -> void:
	if body_renderer:
		body_renderer.apply_morph_profile(profile)

func remove_morph_profile(profile: SdfMorphProfile) -> void:
	if body_renderer:
		body_renderer.remove_morph_profile(profile)

func clear_morph_profiles() -> void:
	if body_renderer:
		body_renderer.clear_morph_profiles()

func active_morph_profile_count() -> int:
	return body_renderer.active_morph_profile_count() if body_renderer else 0

func active_modifier_count() -> int:
	return body_renderer.active_modifier_count() if body_renderer else 0
