class_name ShelterWallCover
extends Node2D

## Emitted when the left room reveal state changes.
signal left_reveal_changed(revealed: bool)
## Emitted when the right room reveal state changes.
signal right_reveal_changed(revealed: bool)
## Emitted when overall reveal state changes (true if any room is revealed).
signal reveal_state_changed(revealed: bool)

@export var left_cover_sprite: Sprite2D
@export var right_cover_sprite: Sprite2D
@export var left_trigger_area: Area2D
@export var right_trigger_area: Area2D
@export var target_sprite: Sprite2D

@export var fade_duration: float = 0.4
@export var normal_alpha: float = 1.0
@export var hidden_alpha: float = 0.0
@export var cover_z_index: int = 35
@export var independent_rooms: bool = true

## Local-space bounds tightly enclosing the left room interior.
@export var left_room_rect: Rect2 = Rect2(-410.5, -115.0, 265.0, 160.0)
## Local-space bounds tightly enclosing the right room interior.
@export var right_room_rect: Rect2 = Rect2(145.0, -115.0, 270.0, 160.0)

var is_left_revealed: bool = false
var is_right_revealed: bool = false

var is_revealed: bool:
	get: return is_left_revealed or is_right_revealed

## Backward compatibility property
var cover_sprite: Sprite2D:
	get: return left_cover_sprite if left_cover_sprite else right_cover_sprite
	set(val): left_cover_sprite = val

## Backward compatibility property
var trigger_area: Area2D:
	get: return left_trigger_area if left_trigger_area else right_trigger_area
	set(val): left_trigger_area = val

var _active_left_players: Array[Node] = []
var _active_right_players: Array[Node] = []
var _left_tween: Tween
var _right_tween: Tween

func _ready() -> void:
	if is_instance_valid(target_sprite):
		target_sprite.visible = true

	if is_instance_valid(left_cover_sprite):
		left_cover_sprite.z_index = cover_z_index
	if is_instance_valid(right_cover_sprite):
		right_cover_sprite.z_index = cover_z_index

	if is_instance_valid(left_trigger_area):
		left_trigger_area.body_entered.connect(_on_left_body_entered)
		left_trigger_area.body_exited.connect(_on_left_body_exited)
		for body: Node in left_trigger_area.get_overlapping_bodies():
			if _is_player(body) and not _active_left_players.has(body):
				_active_left_players.append(body)

	if is_instance_valid(right_trigger_area):
		right_trigger_area.body_entered.connect(_on_right_body_entered)
		right_trigger_area.body_exited.connect(_on_right_body_exited)
		for body: Node in right_trigger_area.get_overlapping_bodies():
			if _is_player(body) and not _active_right_players.has(body):
				_active_right_players.append(body)

	var init_left := _active_left_players.size() > 0 or _check_player_in_rect(left_room_rect)
	var init_right := _active_right_players.size() > 0 or _check_player_in_rect(right_room_rect)
	if not independent_rooms:
		init_left = init_left or init_right
		init_right = init_left

	_set_left_revealed(init_left, true)
	_set_right_revealed(init_right, true)

func _process(_delta: float) -> void:
	_cleanup_players(_active_left_players)
	_cleanup_players(_active_right_players)
	_evaluate_state()

func _cleanup_players(arr: Array[Node]) -> void:
	var i := arr.size() - 1
	while i >= 0:
		if not is_instance_valid(arr[i]):
			arr.remove_at(i)
		i -= 1

func _on_left_body_entered(body: Node) -> void:
	if _is_player(body) and not _active_left_players.has(body):
		_active_left_players.append(body)
		_evaluate_state()

func _on_left_body_exited(body: Node) -> void:
	if _active_left_players.has(body):
		_active_left_players.erase(body)
		_evaluate_state()

func _on_right_body_entered(body: Node) -> void:
	if _is_player(body) and not _active_right_players.has(body):
		_active_right_players.append(body)
		_evaluate_state()

func _on_right_body_exited(body: Node) -> void:
	if _active_right_players.has(body):
		_active_right_players.erase(body)
		_evaluate_state()

func _evaluate_state() -> void:
	var should_left := _active_left_players.size() > 0 or _check_player_in_rect(left_room_rect)
	var should_right := _active_right_players.size() > 0 or _check_player_in_rect(right_room_rect)

	if not independent_rooms:
		var combined := should_left or should_right
		should_left = combined
		should_right = combined

	var prev_overall := is_revealed

	if should_left != is_left_revealed:
		_set_left_revealed(should_left)

	if should_right != is_right_revealed:
		_set_right_revealed(should_right)

	if is_revealed != prev_overall:
		reveal_state_changed.emit(is_revealed)

func _check_player_in_rect(rect: Rect2) -> bool:
	var candidates: Array[Node] = []
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			candidates.append_array(tree.get_nodes_in_group(&"player_input_entities"))
			candidates.append_array(tree.get_nodes_in_group(&"player"))
			if tree.root:
				var player_node: Node = tree.root.find_child("Player", true, false)
				if player_node and not candidates.has(player_node):
					candidates.append(player_node)

	if candidates.is_empty():
		var p := get_parent()
		if p:
			var player_in_parent: Node = p.find_child("Player", true, false)
			if player_in_parent:
				candidates.append(player_in_parent)

	for candidate: Node in candidates:
		if is_instance_valid(candidate) and candidate is Node2D and _is_player(candidate):
			var local_pos := to_local(candidate.global_position)
			if rect.has_point(local_pos):
				return true

	return false

func _is_player(body: Node) -> bool:
	if not is_instance_valid(body):
		return false
	if body.is_in_group(&"player_input_entities") or body.is_in_group(&"player"):
		return true
	if body.name == "Player":
		return true
	if body.get("player_controlled") == true:
		return true
	return false

## Programmatic reveal control for both rooms.
func set_revealed(revealed: bool, immediate: bool = false) -> void:
	_set_left_revealed(revealed, immediate)
	_set_right_revealed(revealed, immediate)
	reveal_state_changed.emit(is_revealed)

## Backward compatibility alias
func _set_revealed(revealed: bool, immediate: bool = false) -> void:
	set_revealed(revealed, immediate)

func _set_left_revealed(revealed: bool, immediate: bool = false) -> void:
	if is_left_revealed == revealed and not immediate:
		return
	is_left_revealed = revealed
	left_reveal_changed.emit(is_left_revealed)

	if not is_instance_valid(left_cover_sprite):
		return

	var target_alpha := hidden_alpha if is_left_revealed else normal_alpha
	_animate_sprite(left_cover_sprite, target_alpha, immediate, _left_tween, func(t: Tween): _left_tween = t)

func _set_right_revealed(revealed: bool, immediate: bool = false) -> void:
	if is_right_revealed == revealed and not immediate:
		return
	is_right_revealed = revealed
	right_reveal_changed.emit(is_right_revealed)

	if not is_instance_valid(right_cover_sprite):
		return

	var target_alpha := hidden_alpha if is_right_revealed else normal_alpha
	_animate_sprite(right_cover_sprite, target_alpha, immediate, _right_tween, func(t: Tween): _right_tween = t)

func _animate_sprite(sprite: Sprite2D, target_alpha: float, immediate: bool, current_tween: Tween, set_tween: Callable) -> void:
	if immediate or fade_duration <= 0.0:
		if current_tween and current_tween.is_valid():
			current_tween.kill()
		sprite.modulate.a = target_alpha
		return

	if current_tween and current_tween.is_valid():
		current_tween.kill()

	var tw := create_tween()
	if tw:
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sprite, "modulate:a", target_alpha, fade_duration)
		set_tween.call(tw)
	else:
		sprite.modulate.a = target_alpha
