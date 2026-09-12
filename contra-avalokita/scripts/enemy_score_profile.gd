class_name EnemyScoreProfile
extends Resource
## Fixed combat-complexity score; deliberately independent of maximum health.
@export var enemy_kind: StringName = &"grunt"
@export var region_id: StringName = &"arena"
@export var base_score := 100
@export var combat_power := 1.0
@export var danger := 0.0
