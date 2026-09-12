class_name SixRealmGlyphs
extends RefCounted
## Game symbol alphabet: 0 Deva, 1 Asura, 2 Human, 3 Animal, 4 Preta, 5 Naraka.
const NAMES := ["Deva", "Asura", "Manushya", "Tiryag", "Preta", "Naraka"]
const NAMES_ZH := ["天道", "修罗道", "人道", "畜生道", "饿鬼道", "地狱道"]
const RADIX := 6

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

static func stroke(canvas: CanvasItem, points: Array, ink: Color, width: float) -> void:
	canvas.draw_polyline(PackedVector2Array(points),ink,width,false)

static func draw_symbol(canvas: CanvasItem, digit: int, ink: Color = Color.WHITE, width: float = 1.0) -> void:
	match digit:
		0: # Closed light cocoon, isolated seed, calm horizontal horizon.
			stroke(canvas,[Vector2(0,-12),Vector2(-5,-7),Vector2(-6,-3),Vector2(-3,0),Vector2(-6,3),Vector2(-5,7),Vector2(0,12),Vector2(5,7),Vector2(6,3),Vector2(3,0),Vector2(6,-3),Vector2(5,-7),Vector2(0,-12)],ink,width)
			canvas.draw_line(Vector2(-9,0),Vector2(9,0),ink,width)
			canvas.draw_circle(Vector2.ZERO,1.5,ink)
		1: # Opposed spearheads; split crossbar.
			stroke(canvas,[Vector2(-5,-5),Vector2(0,-12),Vector2(5,-5)],ink,width)
			stroke(canvas,[Vector2(-5,5),Vector2(0,12),Vector2(5,5)],ink,width)
			canvas.draw_line(Vector2(0,-11),Vector2(0,11),ink,width)
			canvas.draw_line(Vector2(-8,0),Vector2(-2,0),ink,width)
			canvas.draw_line(Vector2(2,0),Vector2(8,0),ink,width)
			stroke(canvas,[Vector2(0,-8),Vector2(-4,0),Vector2(0,8),Vector2(4,0),Vector2(0,-8)],ink,width)
		2: # Balanced bell frame, paired hollow weights.
			stroke(canvas,[Vector2(-4,-3),Vector2(-4,-10),Vector2(-2,-12),Vector2(2,-12),Vector2(4,-10),Vector2(4,-3)],ink,width)
			stroke(canvas,[Vector2(-4,3),Vector2(-4,10),Vector2(-2,12),Vector2(2,12),Vector2(4,10),Vector2(4,3)],ink,width)
			canvas.draw_line(Vector2(-6,0),Vector2(6,0),ink,width)
			canvas.draw_line(Vector2(0,-5),Vector2(0,5),ink,width)
			canvas.draw_arc(Vector2(-8,0),2,0,TAU,12,ink,width,false)
			canvas.draw_arc(Vector2(8,0),2,0,TAU,12,ink,width,false)
		3: # Blunt closed wheel and hollow unseeing eye.
			canvas.draw_arc(Vector2.ZERO,9,0,TAU,20,ink,width*1.4,false)
			canvas.draw_arc(Vector2.ZERO,3,0,TAU,12,ink,width,false)
		4: # Needle throat, two restraints, empty hanging belly.
			canvas.draw_line(Vector2(0,-12),Vector2(0,3),ink,width)
			canvas.draw_line(Vector2(-3,-5),Vector2(3,-5),ink,width)
			canvas.draw_line(Vector2(-3,-2),Vector2(3,-2),ink,width)
			stroke(canvas,[Vector2(-2,2),Vector2(-5,6),Vector2(-4,10),Vector2(0,12),Vector2(4,10),Vector2(5,6),Vector2(2,2)],ink,width)
		5: # Descending terraces, sealed heavy foundation.
			stroke(canvas,[Vector2(-3,-11),Vector2(3,-11),Vector2(3,-5),Vector2(6,-5),Vector2(6,1),Vector2(9,1),Vector2(9,10),Vector2(-9,10),Vector2(-9,1),Vector2(-6,1),Vector2(-6,-5),Vector2(-3,-5),Vector2(-3,-11)],ink,width)
			canvas.draw_line(Vector2(-9,10),Vector2(9,10),ink,width*2)
		-1: canvas.draw_circle(Vector2(0,8),1.2,ink)
