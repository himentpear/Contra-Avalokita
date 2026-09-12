extends Node

signal session_changed(session: Node)

var current_session: Node

func start_session(session: Node) -> void:
	if is_instance_valid(current_session):
		current_session.queue_free()
	current_session = session
	if current_session != null:
		add_child(current_session)
	session_changed.emit(current_session)

func end_session() -> void:
	start_session(null)

func get_score_system() -> Node:
	if is_instance_valid(current_session) and current_session.has_method("get_score_system"):
		return current_session.get_score_system()
	return null
