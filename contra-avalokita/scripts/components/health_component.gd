class_name HealthComponent
extends Node

signal damaged(value: float)
signal healed(value: float)
signal died()
signal revived()
signal stability_broken()
signal stability_recovered()

@export var max_health := 100.0
@export var max_stability := 100.0
@export var stability_recovery_rate := 25.0
@export var stability_recovery_cooldown := 0.5

var health := 100.0
var stability := 100.0
var stability_cooldown_timer := 0.0
var is_dead := false

func setup(p_max_health: float = 100.0, p_max_stability: float = 100.0) -> void:
	max_health = p_max_health
	max_stability = p_max_stability
	health = max_health
	stability = max_stability
	is_dead = false

func damage(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var actual_damage := minf(health, amount)
	health = maxf(0.0, health - amount)
	damaged.emit(actual_damage)
	if health <= 0.0 and not is_dead:
		is_dead = true
		died.emit()
	return actual_damage

func heal(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var actual_heal := minf(max_health - health, amount)
	health = minf(max_health, health + amount)
	if actual_heal > 0.0:
		healed.emit(actual_heal)
	return actual_heal

func consume_stability(amount: float) -> bool:
	if is_dead: return false
	stability = maxf(0.0, stability - amount)
	stability_cooldown_timer = stability_recovery_cooldown
	var broken := stability <= 0.0
	if broken:
		stability_broken.emit()
	return broken

func reset_health() -> void:
	health = max_health
	stability = max_stability
	stability_cooldown_timer = 0.0
	is_dead = false
	revived.emit()

func advance_stability(delta: float) -> void:
	if is_dead: return
	if stability_cooldown_timer > 0.0:
		stability_cooldown_timer = maxf(0.0, stability_cooldown_timer - delta)
	elif stability < max_stability:
		stability = minf(max_stability, stability + stability_recovery_rate * delta)
		if stability >= max_stability:
			stability_recovered.emit()
