extends Node2D
const Glyphs = preload("res://scripts/six_realm_glyphs.gd")

@export var result_duration := 5.0
@export var result_fade_start := 4.25
@export var glyph_spacing := 20.0
@export var glyph_step_delay := 0.065
@export var row_step_delay := 0.12
@export var burst_duration := 0.18
@export var use_chinese := true
@export var font: Font = preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
@export var settlement_y := 16.0
@export var rollup_duration := 0.6
@export var bg_score_font_size := 32
@export var bg_score_opacity := 1.0
@export var bg_score_offset_y := -30.0
@export var bg_score_bold := true
@export var push_transition_duration := 0.32
@export var push_distance := 18.0
@export var show_persistent_panel := false

var displayed_result: Dictionary = {}
var prev_result: Dictionary = {}
var transition_clock: float = -100.0
var last_handled_time: float = -1.0
var scoring: Node

const INK := Color("ffffff")
const MUTED := Color("e2e8e6")
const LABELS_ZH := {
	"perfect_parry":"完美格挡", "precise_dodge":"精准闪避",
	"weakpoint":"弱点打击", "air_kill":"空中击杀", "environment":"环境击杀",
	"low_health":"极限残血", "no_damage":"战斗无伤", "execution":"处决终结",
	"variety":"招式多样", "heavy":"重击终结"
}
const LABELS_EN := {
	"perfect_parry":"PERFECT PARRY", "precise_dodge":"PRECISE DODGE",
	"weakpoint":"WEAKPOINT", "air_kill":"AIR KILL", "environment":"ENVIRONMENT",
	"low_health":"LAST BREATH", "no_damage":"UNTOUCHED", "execution":"EXECUTION",
	"variety":"VARIED ARTS", "heavy":"HEAVY FINISH"
}
const LABELS := LABELS_ZH

func _process(_delta: float) -> void:
	queue_redraw()

func text_at(p: Vector2, value: String, size := 12, color := INK) -> void:
	draw_string(font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered_row(value: String, y: float, size: int, age: float, delay: float, color := INK) -> void:
	var progress := clampf((age-delay)/0.14,0.0,1.0)
	if progress <= 0.0: return
	progress = 1.0-pow(1.0-progress,3.0)
	var tint: Color = color
	tint.a *= progress*result_alpha(age)
	draw_string(font, Vector2(0,roundf(y+6.0*(1.0-progress))), value, HORIZONTAL_ALIGNMENT_CENTER, get_viewport_rect().size.x, size, tint)

func result_alpha(age: float) -> float:
	return 1.0-clampf((age-result_fade_start)/maxf(result_duration-result_fade_start,0.01),0.0,1.0)

func static_number_at(p: Vector2, value: int) -> void:
	var digits := Glyphs.digits(absi(value))
	for i in digits.size():
		draw_set_transform(p+Vector2(i*15.0,0),0,Vector2.ONE*.6)
		Glyphs.draw_symbol(self,digits[i],INK)
	draw_set_transform(Vector2.ZERO)

func get_resonance_text(res: Dictionary) -> String:
	if res.is_empty(): return ""
	var realm_idx: int = clampi(int(res.get("realm", 0)), 0, 5)
	var res_realm: String = Glyphs.NAMES_ZH[realm_idx] if use_chinese else Glyphs.NAMES[realm_idx].to_upper()
	var resonance_val: float = res.get("resonance", 1.0)
	return "%s共鸣   x%.2f" % [res_realm, resonance_val] if use_chinese else "%s RESONANCE   x%.2f" % [res_realm, resonance_val]

func get_visible_tags(res: Dictionary) -> Array[String]:
	var visible: Array[String] = []
	if res.is_empty(): return visible
	var labels_map: Dictionary = LABELS_ZH if use_chinese else LABELS_EN
	var tags: Array = res.get("tags", [])
	for tag in tags:
		var tag_str := String(tag)
		if labels_map.has(tag_str) and visible.size() < 3:
			visible.append(labels_map[tag_str])
	return visible

func get_chain_text(res: Dictionary) -> String:
	if res.is_empty(): return ""
	var streak_val: int = res.get("streak", 0)
	var penalty_val: int = res.get("penalty", 0)
	if use_chinese:
		return "%d 连杀%s" % [streak_val, "   /   重复惩罚" if penalty_val > 0 else ""]
	else:
		return "%d CHAIN%s" % [streak_val, "   /   REPEAT PENALTY" if penalty_val > 0 else ""]

func draw_pushed_text(old_text: String, new_text: String, y: float, size: int, ease_t: float, is_pushing: bool, alpha: float, color := INK) -> void:
	var viewport_width := get_viewport_rect().size.x
	if not is_pushing or old_text == new_text or old_text.is_empty():
		if not new_text.is_empty():
			var tint := color
			tint.a *= alpha
			draw_string(font, Vector2(0, y), new_text, HORIZONTAL_ALIGNMENT_CENTER, viewport_width, size, tint)
		return
	if not old_text.is_empty() and (1.0 - ease_t) > 0.01:
		var old_tint := color
		old_tint.a *= (1.0 - ease_t) * alpha
		var old_y := roundf(y - push_distance * ease_t)
		draw_string(font, Vector2(0, old_y), old_text, HORIZONTAL_ALIGNMENT_CENTER, viewport_width, size, old_tint)
	if not new_text.is_empty() and ease_t > 0.01:
		var new_tint := color
		new_tint.a *= ease_t * alpha
		var new_y := roundf(y + push_distance * (1.0 - ease_t))
		draw_string(font, Vector2(0, new_y), new_text, HORIZONTAL_ALIGNMENT_CENTER, viewport_width, size, new_tint)

func draw_centered_glyphs(value: int, center: Vector2, tint: Color) -> void:
	var digits := Glyphs.digits(absi(value))
	var first_x := center.x - (digits.size() - 1) * glyph_spacing * 0.5
	for i in digits.size():
		draw_set_transform(Vector2(roundf(first_x + i * glyph_spacing), roundf(center.y)), 0, Vector2.ONE * 0.72)
		Glyphs.draw_symbol(self, digits[i], tint, 1.15)
	draw_set_transform(Vector2.ZERO)

func draw_background_score_pushed(old_points: int, new_points: int, center: Vector2, ease_t: float, is_pushing: bool, age: float, alpha: float) -> void:
	var ascent := font.get_ascent(bg_score_font_size)
	var descent := font.get_descent(bg_score_font_size)
	var base_y := roundf(center.y + (ascent - descent) * 0.5 + bg_score_offset_y)
	var viewport_width := get_viewport_rect().size.x

	if is_pushing and old_points != new_points:
		if (1.0 - ease_t) > 0.01:
			var old_prefix := "+" if old_points > 0 else ""
			var old_text := "%s%d" % [old_prefix, old_points]
			var old_y := roundf(base_y - push_distance * ease_t)
			var old_color := Color(INK.r, INK.g, INK.b, bg_score_opacity * (1.0 - ease_t) * alpha)
			if bg_score_bold:
				draw_string_outline(font, Vector2(0, old_y), old_text, HORIZONTAL_ALIGNMENT_CENTER, viewport_width, bg_score_font_size, 2, old_color)
			draw_string(font, Vector2(0, old_y), old_text, HORIZONTAL_ALIGNMENT_CENTER, viewport_width, bg_score_font_size, old_color)

		if ease_t > 0.01:
			var new_prefix := "+" if new_points > 0 else ""
			var new_text := "%s%d" % [new_prefix, new_points]
			var new_y := roundf(base_y + push_distance * (1.0 - ease_t))
			var new_color := Color(INK.r, INK.g, INK.b, bg_score_opacity * ease_t * alpha)
			if bg_score_bold:
				draw_string_outline(font, Vector2(0, new_y), new_text, HORIZONTAL_ALIGNMENT_CENTER, viewport_width, bg_score_font_size, 2, new_color)
			draw_string(font, Vector2(0, new_y), new_text, HORIZONTAL_ALIGNMENT_CENTER, viewport_width, bg_score_font_size, new_color)
		return

	var rollup_start := 0.06
	if age < rollup_start: return
	var progress := clampf((age - rollup_start) / maxf(rollup_duration, 0.01), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var current_score := roundi(lerpf(0.0, float(new_points), eased))
	var prefix := "+" if new_points > 0 else ""
	var text := "%s%d" % [prefix, current_score]
	var appear := clampf((age - rollup_start) / 0.12, 0.0, 1.0)
	var color := Color(INK.r, INK.g, INK.b, bg_score_opacity * appear * alpha)
	if bg_score_bold:
		draw_string_outline(font, Vector2(0, base_y), text, HORIZONTAL_ALIGNMENT_CENTER, viewport_width, bg_score_font_size, 2, color)
	draw_string(font, Vector2(0, base_y), text, HORIZONTAL_ALIGNMENT_CENTER, viewport_width, bg_score_font_size, color)

func update_kill_result(new_result: Dictionary) -> void:
	if new_result.is_empty(): return
	var was_active: bool = not displayed_result.is_empty() and (scoring.clock - float(displayed_result.get("time", -999.0))) <= result_duration
	if was_active:
		prev_result = displayed_result.duplicate(true)
		transition_clock = scoring.clock
	else:
		prev_result.clear()
		transition_clock = -100.0
	displayed_result = new_result.duplicate(true)
	last_handled_time = new_result.get("time", -1.0)

func burst_number(value: int, center: Vector2, age: float, start_delay: float) -> float:
	var digits := Glyphs.digits(absi(value))
	var first_x := center.x-(digits.size()-1)*glyph_spacing*.5
	for i in digits.size():
		var local_age := age-start_delay-i*glyph_step_delay
		if local_age < 0.0: continue
		var appear := clampf(local_age/0.20,0.0,1.0)
		var scale_pop: float
		if appear < 0.42:
			scale_pop = lerpf(0.12,1.28,appear/0.42)
		elif appear < 0.72:
			scale_pop = lerpf(1.28,0.93,(appear-0.42)/0.30)
		else:
			scale_pop = lerpf(0.93,1.0,(appear-0.72)/0.28)
		var point := Vector2(roundf(first_x+i*glyph_spacing),roundf(center.y))
		var flare := 1.0-clampf(local_age/burst_duration,0.0,1.0)
		if flare > 0.0:
			var radius := lerpf(4.0,15.0,1.0-flare)
			var flare_ink := Color(1.0,1.0,1.0,flare*result_alpha(age))
			for ray in 8:
				var direction := Vector2.RIGHT.rotated(TAU*ray/8.0)
				draw_line((point+direction*(radius-3.0)).round(),(point+direction*radius).round(),flare_ink,1.0)
		var glyph_ink := INK
		glyph_ink.a = minf(local_age/0.055,1.0)*result_alpha(age)
		draw_set_transform(point,0,Vector2.ONE*(0.72*scale_pop))
		Glyphs.draw_symbol(self,digits[i],glyph_ink,1.15)
	draw_set_transform(Vector2.ZERO)
	return start_delay+maxi(digits.size()-1,0)*glyph_step_delay+0.22

func _draw() -> void:
	if not scoring: return
	if scoring.last_result.is_empty():
		displayed_result.clear()
		prev_result.clear()
		last_handled_time = -1.0
	elif scoring.last_result.get("time", -2.0) != last_handled_time:
		update_kill_result(scoring.last_result)

	if displayed_result.is_empty(): return
	var age: float = scoring.clock - displayed_result.get("time", 0.0)
	var result_active := age >= 0.0 and age <= result_duration

	# Corner total is now moved to F5 Details Menu; only draw here if explicitly enabled.
	if not result_active:
		if show_persistent_panel:
			draw_rect(Rect2(451,82,181,76),Color("0c161d"))
			text_at(Vector2(462,95), "击杀得分 / 六进制" if use_chinese else "KILL SCORE / BASE 6", 9)
			static_number_at(Vector2(470,110),scoring.total)
			var realm_name: String = Glyphs.NAMES_ZH[clampi(scoring.realm,0,5)] if use_chinese else Glyphs.NAMES[clampi(scoring.realm,0,5)].to_upper()
			var chain_str: String = "%s / %d 连杀" % [realm_name, scoring.streak] if use_chinese else "%s / %d CHAIN" % [realm_name, scoring.streak]
			text_at(Vector2(462,130), chain_str, 9)
			text_at(Vector2(462,146), "F3 目标   F4 道相" if use_chinese else "F3 TARGET   F4 REALM", 9)
		return

	var alpha := result_alpha(age)
	var viewport_width := get_viewport_rect().size.x
	var panel := Rect2(roundf((viewport_width-300.0)*.5), settlement_y, 300, 160)
	draw_line(Vector2(panel.position.x+72, settlement_y+2), Vector2(panel.end.x-72, settlement_y+2), Color(0.88,0.94,0.92,0.75*alpha), 1.0)
	centered_row("击杀结算" if use_chinese else "KILL SETTLED", settlement_y-4, 9, age, 0.0, MUTED)

	var is_pushing: bool = not prev_result.is_empty() and (scoring.clock - transition_clock) <= push_transition_duration
	var push_t: float = clampf((scoring.clock - transition_clock) / maxf(push_transition_duration, 0.01), 0.0, 1.0) if is_pushing else 1.0
	var ease_push := 1.0 - pow(1.0 - push_t, 3.0)

	var number_center := Vector2(viewport_width*.5, settlement_y+46)
	var old_points: int = int(prev_result.get("points", 0)) if is_pushing else 0
	var new_points: int = int(displayed_result.get("points", 0))
	draw_background_score_pushed(old_points, new_points, number_center, ease_push, is_pushing, age, alpha)

	var next_row: float = 0.0
	if is_pushing:
		if old_points != new_points and (1.0 - ease_push) > 0.01:
			var old_glyph_tint := Color(INK.r, INK.g, INK.b, INK.a * (1.0 - ease_push) * alpha)
			draw_centered_glyphs(old_points, number_center + Vector2(0, -push_distance * ease_push), old_glyph_tint)
		var new_glyph_center := number_center + Vector2(0, push_distance * (1.0 - ease_push))
		next_row = burst_number(new_points, new_glyph_center, age, 0.10)
	else:
		next_row = burst_number(new_points, number_center, age, 0.10)

	var res_y := settlement_y + 79
	var old_res_text := get_resonance_text(prev_result) if is_pushing else ""
	var new_res_text := get_resonance_text(displayed_result)
	if is_pushing:
		draw_pushed_text(old_res_text, new_res_text, res_y, 10, ease_push, true, alpha, MUTED)
	else:
		centered_row(new_res_text, res_y, 10, age, next_row, MUTED)

	var old_tags: Array[String] = []
	if is_pushing:
		old_tags = get_visible_tags(prev_result)
	var new_tags: Array[String] = get_visible_tags(displayed_result)
	var max_tags := maxi(old_tags.size(), new_tags.size())
	var delay := next_row + row_step_delay
	for i in max_tags:
		var tag_y := settlement_y + 98 + i * 14
		var old_tag_str: String = old_tags[i] if i < old_tags.size() else ""
		var new_tag_str: String = new_tags[i] if i < new_tags.size() else ""
		if is_pushing:
			draw_pushed_text(old_tag_str, new_tag_str, tag_y, 9, ease_push, true, alpha, INK)
		else:
			if not new_tag_str.is_empty():
				centered_row(new_tag_str, tag_y, 9, age, delay + i * row_step_delay)

	var chain_y := settlement_y + 148
	var old_chain_text := get_chain_text(prev_result) if is_pushing else ""
	var new_chain_text := get_chain_text(displayed_result)
	if is_pushing:
		draw_pushed_text(old_chain_text, new_chain_text, chain_y, 9, ease_push, true, alpha, MUTED)
	else:
		var chain_delay := delay + new_tags.size() * row_step_delay
		centered_row(new_chain_text, chain_y, 9, age, chain_delay, MUTED)
