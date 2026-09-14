class_name ContentDefinition
extends Resource

@export var id: StringName
@export var content_type: StringName
@export var display_name: String = ""
@export var tags: Array[StringName] = []
@export var resource: Resource
@export var metadata: Dictionary = {}

