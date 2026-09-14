extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var output: RichTextLabel = $Panel/Margin/VBox/Output
@onready var input: LineEdit = $Panel/Margin/VBox/Input

func _ready() -> void:
	panel.visible = false
	input.text_submitted.connect(_on_submitted)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:
			set_open(not panel.visible)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_P and event.ctrl_pressed and event.shift_pressed:
			set_open(true)
			input.text = ""
			input.placeholder_text = "Command Palette"
			get_viewport().set_input_as_handled()

func set_open(value: bool) -> void:
	panel.visible = value
	if value:
		input.grab_focus()
	else:
		input.release_focus()

func _on_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	var result: Variant = CommandRegistry.execute(text)
	output.append_text("\n> %s\n%s" % [text, str(result)])
	input.clear()

