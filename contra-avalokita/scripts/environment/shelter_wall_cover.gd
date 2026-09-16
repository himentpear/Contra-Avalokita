class_name ShelterWallCover
extends Node2D

## Emitted when the reveal state changes (true = wall hidden, showing inside; false = wall opaque).
signal reveal_state_changed(revealed: bool)

@export var cover_sprite: Sprite2D
@export var target_sprite: Sprite2D
@export var trigger_area: Area2D
@export var fade_duration: float = 0.4
@export var normal_alpha: float = 1.0
@export var hidden_alpha: float = 0.0
@export var trigger_half_size: Vector2 = Vector2(500.0, 180.0)

var is_revealed: bool = false
var _active_players: Array[Node] = []
var _tween: Tween

func _ready() -> void:
	if is_instance_valid(target_sprite):
		target_sprite.visible = true

	if is_instance_valid(trigger_area):
		trigger_area.body_entered.connect(_on_body_entered)
		trigger_area.body_exited.connect(_on_body_exited)
		for body: Node in trigger_area.get_overlapping_bodies():
			if _is_player(body) and not _active_players.has(body):
				_active_players.append(body)

	var initial_reveal := _active_players.size() > 0 or _check_proximity_fallback()
	_set_revealed(initial_reveal, true)

func _process(_delta: float) -> void:
	var i := _active_players.size() - 1
	while i >= 0:
		if not is_instance_valid(_active_players[i]):
			_active_players.remove_at(i)
		i -= 1

	_evaluate_state()

func _on_body_entered(body: Node) -> void:
	if _is_player(body) and not _active_players.has(body):
		_active_players.append(body)
		_evaluate_state()

func _on_body_exited(body: Node) -> void:
	if _active_players.has(body):
		_active_players.erase(body)
		_evaluate_state()

func _evaluate_state() -> void:
	var should_reveal := _active_players.size() > 0 or _check_proximity_fallback()
	if should_reveal != is_revealed:
		_set_revealed(should_reveal)

func _check_proximity_fallback() -> bool:
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
			if absf(local_pos.x) <= trigger_half_size.x and absf(local_pos.y) <= trigger_half_size.y:
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

func set_revealed(revealed: bool, immediate: bool = false) -> void:
	_set_revealed(revealed, immediate)

func _set_revealed(revealed: bool, immediate: bool = false) -> void:
	if is_revealed == revealed and not immediate:
		return
	is_revealed = revealed
	reveal_state_changed.emit(is_revealed)

	if not is_instance_valid(cover_sprite):
		return

	var target_alpha := hidden_alpha if is_revealed else normal_alpha

	if immediate or fade_duration <= 0.0:
		if _tween and _tween.is_valid():
			_tween.kill()
		cover_sprite.modulate.a = target_alpha
		return

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if _tween:
		_tween.set_trans(Tween.TRANS_SINE)
		_tween.set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(cover_sprite, "modulate:a", target_alpha, fade_duration)
	else:
		cover_sprite.modulate.a = target_alpha
