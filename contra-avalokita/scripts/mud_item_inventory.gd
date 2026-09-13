class_name MudItemInventory
extends RefCounted

signal changed

var _items: Dictionary = {}

func obtain(item: CoyoteItem) -> void:
	if item == null or item.id.is_empty(): return
	_items[item.id] = item
	changed.emit()

func remove(item_id: StringName) -> void:
	if _items.erase(item_id): changed.emit()

func clear() -> void:
	if _items.is_empty(): return
	_items.clear()
	changed.emit()

func has(item_id: StringName) -> bool:
	return _items.has(item_id)

func items() -> Array[CoyoteItem]:
	var result: Array[CoyoteItem] = []
	for item: CoyoteItem in _items.values(): result.append(item)
	return result

func aggregate_movement_modifiers() -> Dictionary:
	var result := {
		&"coyote_time_bonus": 0.0,
		&"jump_buffer_time_bonus": 0.0,
		&"coyote_horizontal_jump_multiplier": 1.0,
		&"coyote_vertical_jump_multiplier": 1.0,
		&"coyote_initial_gravity_multiplier": 1.0,
		&"coyote_initial_gravity_duration": 0.0,
	}
	for item: CoyoteItem in _items.values():
		for key: Variant in item.modifiers:
			var id := StringName(key)
			var value := float(item.modifiers[key])
			if id in [&"coyote_horizontal_jump_multiplier", &"coyote_vertical_jump_multiplier", &"coyote_initial_gravity_multiplier"]:
				result[id] = float(result.get(id, 1.0)) * value
			elif id == &"coyote_initial_gravity_duration":
				result[id] = maxf(float(result[id]), value)
			else:
				result[id] = float(result.get(id, 0.0)) + value
	return result
