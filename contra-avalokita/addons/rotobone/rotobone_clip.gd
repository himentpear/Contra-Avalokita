@tool
class_name RotoBoneClip
extends Resource

## Serializable animation-reference interface used by RotoBone.
## The texture is optional so metadata can be shared before assets are imported.

@export var clip_id: StringName = &""
@export var texture: Texture2D
@export var frame_size: Vector2i = Vector2i(48, 48)
@export_range(1, 4096, 1) var frame_count: int = 1
@export var frame_durations_ms: PackedInt32Array = PackedInt32Array([100])
@export var loop: bool = true
@export_enum("feet", "hip", "contact", "center", "custom") var anchor_mode: String = "feet"
@export var anchor_px: Vector2 = Vector2(24.0, 40.0)
@export_enum("right", "left", "side", "back", "front", "neutral") var source_facing: String = "right"
@export var tags: PackedStringArray = PackedStringArray()


func get_duration_seconds() -> float:
	var total_ms := 0
	for duration in frame_durations_ms:
		total_ms += maxi(duration, 1)
	if total_ms <= 0:
		total_ms = maxi(frame_count, 1) * 100
	return float(total_ms) / 1000.0


func get_frame_duration_ms(index: int) -> int:
	if frame_durations_ms.is_empty():
		return 100
	return maxi(frame_durations_ms[clampi(index, 0, frame_durations_ms.size() - 1)], 1)


func frame_at_time(time_seconds: float) -> int:
	if frame_count <= 1:
		return 0
	var total := get_duration_seconds()
	if total <= 0.0:
		return 0
	var t := time_seconds
	if loop:
		t = fposmod(t, total)
	else:
		t = clampf(t, 0.0, maxf(total - 0.000001, 0.0))
	var cursor := 0.0
	for i in range(frame_count):
		cursor += float(get_frame_duration_ms(i)) / 1000.0
		if t < cursor:
			return i
	return frame_count - 1


func source_rect(index: int) -> Rect2:
	if texture == null or frame_size.x <= 0 or frame_size.y <= 0:
		return Rect2()
	var columns := maxi(int(texture.get_width() / frame_size.x), 1)
	var safe_index := clampi(index, 0, maxi(frame_count - 1, 0))
	var column := safe_index % columns
	var row := int(safe_index / columns)
	return Rect2(
		Vector2(column * frame_size.x, row * frame_size.y),
		Vector2(frame_size)
	)


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if frame_size.x <= 0 or frame_size.y <= 0:
		problems.append("frame_size must be positive")
	if frame_count <= 0:
		problems.append("frame_count must be positive")
	if not frame_durations_ms.is_empty() and frame_durations_ms.size() != frame_count:
		problems.append("frame_durations_ms should contain one duration per frame")
	if texture != null:
		if texture.get_width() % frame_size.x != 0:
			problems.append("texture width is not divisible by frame width")
		if texture.get_height() % frame_size.y != 0:
			problems.append("texture height is not divisible by frame height")
	return problems
