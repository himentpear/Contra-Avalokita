class_name ConsoleAutocomplete
extends RefCounted

static func suggestions(text: String) -> PackedStringArray:
	return CommandRegistry.get_suggestions(text.strip_edges())

