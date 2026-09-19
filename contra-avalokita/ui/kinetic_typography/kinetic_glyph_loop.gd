@tool
extends Control
## Six-second kinetic glyph loop reconstructed from the supplied 720 px movie.
## Each cell is drawn independently from a transparent glyph atlas; no video is played.

const OPENING: Texture2D = preload("res://assets/kinetic_typography/opening_states.png")
const CYCLE: Texture2D = preload("res://assets/kinetic_typography/glyph_cycle.png")
const ACTIVE_INDEX: Texture2D = preload("res://assets/kinetic_typography/state_active_index.png")
const GLYPH_CLOCK: Texture2D = preload("res://assets/kinetic_typography/glyph_clock.png")
const WHITE_CELLS: Texture2D = preload("res://assets/kinetic_typography/white_edge_cells.png")
const WHITE_INDEX: Texture2D = preload("res://assets/kinetic_typography/white_edge_index.png")
const SEALS: Texture2D = preload("res://assets/kinetic_typography/seal_states.png")
const LOGICAL_SIZE := 720.0
const GRID := 13
const TILE := 55.0
const PITCH := 55.0
const LOOP_SECONDS := 6.0
const GLYPH_HZ := 30.0
const OPENING_FRAMES := 16
const CYCLE_FRAMES := 16
const STATE_TIMES := [0.5, 1.0, 1.5, 2.0, 2.5, 2.9, 3.2, 3.5, 3.8,
	4.2, 4.5, 4.8, 4.9, 5.0, 5.1, 5.2, 5.3, 5.5]

var _white_index_map: Image
var _active_index_map: Image
var _glyph_clock_map: Image

@export var auto_play := true:
	set(value):
		auto_play = value
		if is_inside_tree():
			set_process(value)
@export_range(0.0, 6.0, 0.01) var loop_time := 0.0:
	set(value):
		loop_time = fposmod(value, LOOP_SECONDS)
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_white_index_map = WHITE_INDEX.get_image()
	_active_index_map = ACTIVE_INDEX.get_image()
	_glyph_clock_map = GLYPH_CLOCK.get_image()
	set_process(auto_play)
	queue_redraw()


func _process(delta: float) -> void:
	if auto_play:
		loop_time = fposmod(loop_time + delta, LOOP_SECONDS)


func seek(seconds: float) -> void:
	loop_time = seconds


func _birth_time(column: int, row: int) -> float:
	var vertical := minf(absf(row - 6) * 0.25,
		minf(row * 0.25 + 0.25, (12 - row) * 0.25 + 0.25))
	return absf(column - 6) * 0.25 + vertical


func _state_index(time: float) -> int:
	var best := 0
	var nearest := INF
	for index in range(STATE_TIMES.size()):
		var difference := absf(time - STATE_TIMES[index])
		if difference < nearest:
			nearest = difference
			best = index
	return best


func _white_override_index(time: float, column: int, row: int) -> int:
	if _white_index_map == null:
		_white_index_map = WHITE_INDEX.get_image()
	var frame := _glyph_tick(time)
	var encoded := _white_index_map.get_pixel(column, frame * GRID + row)
	return roundi(encoded.r * 255.0) + roundi(encoded.g * 255.0) * 256 - 1


func _glyph_tick(time: float) -> int:
	return clampi(floori(time * GLYPH_HZ + 0.00001), 0, 179)


func _phase_tick(tick: int) -> int:
	if _glyph_clock_map == null:
		_glyph_clock_map = GLYPH_CLOCK.get_image()
	return roundi(_glyph_clock_map.get_pixel(0, tick).r * 255.0)


func _cycle_index(phase_tick: int, column: int, row: int) -> int:
	# Every cell shares the 30 Hz clock; spatial phase keeps the field varied.
	return posmod(phase_tick + column * 5 + row * 3, CYCLE_FRAMES)


func _cell_source(block: int, column: int, row: int) -> Rect2:
	return Rect2(Vector2((block % 4) * GRID + column,
		floori(float(block) / 4.0) * GRID + row) * TILE,
		Vector2.ONE * TILE)


func _state_cell_active(state: int, column: int, row: int) -> bool:
	if _active_index_map == null:
		_active_index_map = ACTIVE_INDEX.get_image()
	return _active_index_map.get_pixel(column, state * GRID + row).r > 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var fit := minf(size.x / LOGICAL_SIZE, size.y / LOGICAL_SIZE)
	if fit <= 0.0:
		return
	var origin := (size - Vector2.ONE * LOGICAL_SIZE * fit) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * fit)
	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE * LOGICAL_SIZE), Color.BLACK)
	var tick := _glyph_tick(loop_time)
	if tick < OPENING_FRAMES:
		for row in range(GRID):
			for column in range(GRID):
				var center := Vector2(360.0 + (column - 6) * PITCH,
					360.0 + (row - 6) * PITCH)
				draw_texture_rect_region(OPENING,
					Rect2(center - Vector2.ONE * 27.0, Vector2.ONE * TILE),
					_cell_source(tick, column, row), Color.WHITE)
		return
	var state := _state_index(loop_time)
	var phase_tick := _phase_tick(tick)
	for row in range(GRID):
		for column in range(GRID):
			var override_index := _white_override_index(loop_time, column, row)
			if (loop_time < 4.0 and override_index < 0
					and loop_time + 0.0001 < _birth_time(column, row)):
				continue
			if (loop_time >= 4.0 and override_index < 0
					and not _state_cell_active(state, column, row)):
				continue
			var center := Vector2(360.0 + (column - 6) * PITCH,
				360.0 + (row - 6) * PITCH)
			var target := Rect2(center - Vector2.ONE * 27.0,
				Vector2.ONE * TILE)
			if override_index >= 0:
				var white_source := Rect2(Vector2(
					override_index % 32,
					floori(float(override_index) / 32.0)) * TILE,
					Vector2.ONE * TILE)
				draw_texture_rect_region(WHITE_CELLS, target, white_source, Color.WHITE)
			else:
				draw_texture_rect_region(CYCLE, target,
					_cell_source(_cycle_index(phase_tick, column, row), column, row), Color.WHITE)
	if state >= 9:
		var seal_index := state - 9
		var seal_source := Rect2(
			Vector2(seal_index % 3, floori(float(seal_index) / 3.0)) * 400.0,
			Vector2.ONE * 400.0)
		draw_texture_rect_region(SEALS,
			Rect2(Vector2.ONE * 160.0, Vector2.ONE * 400.0),
			seal_source, Color.WHITE)
		# The 30 fps white edge cells belong above the more sparsely sampled seal.
		for row in range(GRID):
			for column in range(GRID):
				var override_index := _white_override_index(loop_time, column, row)
				if override_index < 0:
					continue
				var center := Vector2(360.0 + (column - 6) * PITCH,
					360.0 + (row - 6) * PITCH)
				var target := Rect2(center - Vector2.ONE * 27.0,
					Vector2.ONE * TILE)
				var source := Rect2(Vector2(
					override_index % 32,
					floori(float(override_index) / 32.0)) * TILE,
					Vector2.ONE * TILE)
				draw_texture_rect_region(WHITE_CELLS, target, source, Color.WHITE)
