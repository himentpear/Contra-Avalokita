class_name CoyoteItemWindow
extends PanelContainer

var item: CoyoteItem
var _name_label: Label
var _rarity_label: Label
var _effect_label: Label
var _flavor_label: Label
var _tags_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(250.0, 145.0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var icon_slot := ColorRect.new()
	icon_slot.custom_minimum_size = Vector2(28.0, 28.0)
	icon_slot.color = Color("26383b")
	header.add_child(icon_slot)
	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_name_label)
	_rarity_label = Label.new()
	header.add_child(_rarity_label)
	_effect_label = Label.new()
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.add_theme_color_override("font_color", Color("dce8c2"))
	column.add_child(_effect_label)
	var separator := HSeparator.new()
	column.add_child(separator)
	_flavor_label = Label.new()
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.add_theme_color_override("font_color", Color("81947e"))
	column.add_child(_flavor_label)
	_tags_label = Label.new()
	_tags_label.add_theme_color_override("font_color", Color("a9c9c2"))
	column.add_child(_tags_label)
	_refresh()

func set_item(value: CoyoteItem) -> void:
	item = value
	if is_node_ready(): _refresh()

func _refresh() -> void:
	if item == null or _name_label == null: return
	_name_label.text = item.display_name
	_rarity_label.text = String(item.rarity)
	_effect_label.text = item.mechanical_text
	_flavor_label.text = item.flavor_text
	var tag_text: PackedStringArray = []
	for tag in item.tags: tag_text.append("#" + String(tag))
	_tags_label.text = " ".join(tag_text)
