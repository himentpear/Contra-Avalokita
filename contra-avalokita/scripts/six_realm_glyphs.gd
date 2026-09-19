class_name SixRealmGlyphs
extends RefCounted
## Game symbol alphabet: 0 Deva, 1 Asura, 2 Human, 3 Animal, 4 Preta, 5 Naraka.
const NAMES := ["Deva", "Asura", "Manushya", "Tiryag", "Preta", "Naraka"]
const NAMES_ZH := ["天道", "修罗道", "人道", "畜生道", "饿鬼道", "地狱道"]
const RADIX := 6
const GLYPH_SIZE := 24.0
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/six_realms/01_deva.svg"),
	preload("res://assets/six_realms/02_asura.svg"),
	preload("res://assets/six_realms/03_manushya.svg"),
	preload("res://assets/six_realms/04_tiryag.svg"),
	preload("res://assets/six_realms/05_preta.svg"),
	preload("res://assets/six_realms/06_naraka.svg"),
]

static func digits(value: int) -> Array[int]:
	var result: Array[int] = []
	value = maxi(value,0)
	if value == 0: return [0]
	while value > 0:
		result.push_front(value % RADIX)
		@warning_ignore("integer_division")
		value = value / RADIX
	return result

static func number_tokens(value: float) -> Array[int]:
	# Two base-six fractional places; -1 is the radix point, not a seventh digit.
	var units := roundi(maxf(0,value)*36.0)
	@warning_ignore("integer_division")
	var result := digits(units/36)
	var fraction := units%36
	if fraction != 0:
		result.append(-1)
		@warning_ignore("integer_division")
		result.append(fraction/6)
		if fraction%6 != 0: result.append(fraction%6)
	return result

static func draw_symbol(canvas: CanvasItem, digit: int, ink: Color = Color.WHITE, _width: float = 1.0) -> void:
	if digit == -1:
		canvas.draw_circle(Vector2(0, 8), 1.2, ink)
		return
	if digit < 0 or digit >= TEXTURES.size():
		return
	# The supplied white SVG artwork is rasterized at 24 px and tinted at draw time.
	# Keep the established centered 24 px cell and the existing animation transforms.
	canvas.draw_texture_rect(TEXTURES[digit], Rect2(-GLYPH_SIZE * 0.5, -GLYPH_SIZE * 0.5, GLYPH_SIZE, GLYPH_SIZE), false, ink)
