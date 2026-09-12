extends Node
signal kill_scored(result: Dictionary)
signal score_changed(total: int)
@export_range(.8,1.5) var difficulty := 1.0
@export_enum("Deva","Asura","Manushya","Tiryag","Preta","Naraka") var realm := 1
@export var combo_timeout := 12.0
@export var encounter_timeout := 8.0
@export var behavior_window := 4.0
@export var low_health_ratio := .15
@export var strength_weight := .35
@export var crowd_weight := .25
@export var danger_weight := .15
@export var quality_rewards := {"perfect_parry":.20,"precise_dodge":.15,"weakpoint":.10,"air_kill":.10,"environment":.20,"low_health":.25,"no_damage":.30,"execution":.15,"variety":.15}
@export var repeated_attack_penalty := .05
@export var heavy_hit_penalty := .15
var total := 0
var streak := 0
var clock := 0.0
var last_kill := -1000.0
var repeats: Dictionary = {}
var encounters: Dictionary = {}
var paid: Dictionary = {}
var behaviors: Dictionary = {}
var last_result: Dictionary = {}
var recent_damage: Dictionary = {}
var hud: Node2D
@export var combat_radius := 240.0

func _ready() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 30
	add_child(overlay)
	hud = preload("res://scripts/kill_score_hud.gd").new()
	hud.name = "KillScoreHUD"
	hud.scoring = self
	overlay.add_child(hud)

func _process(delta: float) -> void:
	clock += delta
	if clock-last_kill > combo_timeout: streak = 0
	for id in encounters.keys():
		if clock-encounters[id].time > encounter_timeout or encounters[id].target.get_ref() == null:
			encounters.erase(id)
	for id in behaviors.keys():
		if clock-behaviors[id].time > behavior_window: behaviors.erase(id)
	for id in recent_damage.keys():
		if clock-recent_damage[id] > encounter_timeout: recent_damage.erase(id)

func reset_run() -> void:
	total=0; streak=0; last_kill=-1000; repeats.clear(); encounters.clear(); paid.clear(); behaviors.clear(); last_result.clear()
	score_changed.emit(total)
	recent_damage.clear()

func eligible(actor: Node) -> bool:
	return is_instance_valid(actor) and (actor.get("player_controlled") == true or actor.get("score_credit_enabled") == true)

## Explicit hooks for mechanics such as perfect parry/execute; ordinary block is not parry.
func mark_behavior(actor: Node, tag: StringName) -> void:
	if not eligible(actor): return
	var id := actor.get_instance_id()
	if not behaviors.has(id) or clock-behaviors[id].time > behavior_window:
		behaviors[id] = {"time":clock,"tags":{}}
	behaviors[id].time=clock
	behaviors[id].tags[String(tag)]=true

func note_heavy_hit(actor: Node) -> void:
	if eligible(actor): streak = floori(streak*.5)
	for entry in encounters.values():
		if entry.attacker_id == actor.get_instance_id(): entry.heavy = true

func record_hit(victim: Node2D, event: RefCounted, actual_damage: float) -> void:
	if actual_damage <= 0: return
	var victim_id := victim.get_instance_id()
	if eligible(victim): recent_damage[victim_id] = clock
	# Enemies engaging first still count as active combatants and invalidate no-damage.
	if eligible(victim) and is_instance_valid(event.attacker) and event.attacker.get("score_profile") != null:
		register_encounter(event.attacker,victim)
	for entry in encounters.values():
		if entry.attacker_id == victim_id:
			entry.hurt = true
			entry.time = clock
			if event.hit_type in [&"HeavyHit",&"Knockdown"]: entry.heavy = true
	if eligible(victim) and event.hit_type in [&"HeavyHit",&"Knockdown"]:
		note_heavy_hit(victim)
	var attacker: Node = event.attacker
	if not eligible(attacker) or attacker == victim or victim.get("score_profile") == null: return
	var key := str(victim_id)+":"+str(victim.get("score_life_id"))
	if paid.has(key): return
	register_encounter(victim,attacker)
	var entry: Dictionary = encounters[key]
	entry.time=clock
	for tag in event.score_tags: entry.tags[String(tag)] = true
	if behaviors.has(attacker.get_instance_id()) and clock-behaviors[attacker.get_instance_id()].time <= behavior_window:
		entry.tags.merge(behaviors[attacker.get_instance_id()].tags,true)
	var attack_name := String(event.attack_name)
	if event.attack_token != entry.last_token and not attack_name.is_empty():
		if entry.last_attack == attack_name: entry.repeat += 1
		entry.last_attack=attack_name
		entry.last_token=event.attack_token
		entry.attacks[attack_name]=true
	if victim.get("health") > 0: return
	var tags: Dictionary = entry.tags.duplicate()
	if not attacker.is_on_floor(): tags.air_kill=true
	if attacker.health/maxf(attacker.max_health,.001) <= low_health_ratio: tags.low_health=true
	if not entry.hurt: tags.no_damage=true
	if entry.attacks.size() >= 3: tags.variety=true
	if event.hit_type in [&"HeavyHit",&"Knockdown"]: tags.heavy=true
	var others := 0
	for other in encounters.values():
		var enemy: Node2D = other.target.get_ref()
		if other.attacker_id == entry.attacker_id and other != entry and is_instance_valid(enemy) and enemy.global_position.distance_to(attacker.global_position) <= combat_radius: others += 1
	var profile: Resource = victim.score_profile
	var level_gap := maxf(0,profile.combat_power/maxf(attacker.score_combat_power,.01)-1)
	var danger: float = profile.danger+(1.0 if tags.has("low_health") else 0.0)
	var threat := clampf(1+strength_weight*level_gap+crowd_weight*others+danger_weight*danger,1,3)
	var quality := 1.0
	for tag in quality_rewards:
		if tags.has(tag): quality += quality_rewards[tag]
	quality -= entry.repeat*repeated_attack_penalty
	if entry.heavy: quality -= heavy_hit_penalty
	if tags.has("safe_ranged"): quality -= .20
	quality=clampf(quality,.6,2)
	settle(key,profile,threat,quality,resonance(tags),tags)
	encounters.erase(key)

## AI may call this on aggro; N counts engaged nearby enemies, not idle bystanders.
func register_encounter(enemy: Node2D, actor: Node) -> void:
	if not eligible(actor) or enemy.get("score_profile") == null: return
	var key := str(enemy.get_instance_id())+":"+str(enemy.get("score_life_id"))
	if paid.has(key): return
	var id := actor.get_instance_id()
	if not encounters.has(key) or encounters[key].attacker_id != id:
		encounters[key]={"target":weakref(enemy),"attacker_id":id,"tags":{},"attacks":{},"last_attack":"","last_token":-1,"repeat":0,"hurt":recent_damage.has(id) and clock-recent_damage[id] <= encounter_timeout,"heavy":false,"time":clock}
	encounters[key].time=clock

func resonance(tags: Dictionary) -> float:
	var likes := [["no_damage","weakpoint","precise_dodge"],["perfect_parry","variety","heavy"],["variety","perfect_parry","precise_dodge"],["environment","heavy","dismember"],["lifesteal","loot","low_health"],["execution","heavy","pressure"]]
	var matches := 0
	for tag in likes[clampi(realm,0,5)]:
		if tags.has(tag): matches += 1
	if tags.has("safe_ranged") and realm in [1,5]: return .8
	return 1.4 if matches >= 2 else (1.2 if matches == 1 else 1.0)

static func calculate(base: int, threat: float, quality: float, combo: float, resonance_value: float, difficulty_value: float, penalty: int) -> int:
	return roundi(base*threat*quality*combo*resonance_value*difficulty_value)-penalty

func settle(key: String, profile: Resource, threat: float, quality: float, resonance_value: float, tags: Dictionary, extra_penalty: int = 0) -> Dictionary:
	if paid.has(key): return {}
	paid[key]=true
	if clock-last_kill > combo_timeout: streak=0
	streak += 1
	last_kill=clock
	var bucket := String(profile.region_id)+"/"+String(profile.enemy_kind)
	var count := int(repeats.get(bucket,0))+1
	repeats[bucket]=count
	var farm_factor := clampf((count-2)*.2,0,.8)
	var penalty := roundi(profile.base_score*farm_factor)+maxi(extra_penalty,0)
	var combo := 1+minf(streak*.04,.8)
	var points := calculate(profile.base_score,clampf(threat,1,3),clampf(quality,.6,2),combo,clampf(resonance_value,.8,1.4),clampf(difficulty,.8,1.5),penalty)
	total += points
	last_result={"points":points,"total":total,"base":profile.base_score,"threat":threat,"quality":quality,"combo":combo,"resonance":resonance_value,"difficulty":difficulty,"penalty":penalty,"streak":streak,"realm":realm,"tags":tags.keys(),"time":clock}
	kill_scored.emit(last_result.duplicate(true))
	score_changed.emit(total)
	return last_result
