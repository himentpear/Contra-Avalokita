class_name CoyoteItemGallery
extends GridContainer

const ITEM_PATHS := [
	"res://content/base/items/coyote/wile_glance.tres",
	"res://content/base/items/coyote/suspended_absurdity.tres",
	"res://content/base/items/coyote/hermes_winged_boots.tres",
	"res://content/base/items/coyote/dear_cruel_gravity.tres",
	"res://content/base/items/coyote/three_eyed_pardon.tres",
]
const WINDOW := preload("res://ui/items/coyote_item_window.tscn")

func _ready() -> void:
	columns = 3
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)
	for path in ITEM_PATHS:
		var window := WINDOW.instantiate() as CoyoteItemWindow
		window.set_item(load(path) as CoyoteItem)
		add_child(window)
