class_name SeedManager
extends RefCounted

var seed: int
var random := RandomNumberGenerator.new()

func configure(value: int) -> void:
	seed = value
	random.seed = value

