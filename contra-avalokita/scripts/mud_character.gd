class_name MudCharacter
extends CharacterBody2D
signal state_changed(previous: StringName, current: StringName)
signal damaged(amount: float)
@export var player_controlled := true
@export var move_speed := 105.0
@export_range(0.1, 0.9) var walk_speed_ratio := 0.43
@export var acceleration := 700.0
@export var gravity := 650.0
@export var jump_velocity := -245.0
@export var attack_duration := 0.62
@export var max_health := 100.0
@export var allow_air_attack := true
var health := 100.0
var state: StringName = &"Idle"
var attack_time := 0.0
var land_time := 0.0
var facing := 1.0
var move_intent := 0.0
var jump_requested := false
var attack_requested := false
@onready var visual: Node2D = $Visual
@onready var rig: MudRig = $Visual/Rig
@onready var body_renderer: MudBodyRenderer = $Visual/MudBodyRenderer
@onready var eyes: MudEyeController = $Visual/Eyes
@onready var equipment: EquipmentManager = $Visual/Equipment
@onready var weapons: WeaponManager = $Visual/WeaponSlots

func _ready() -> void:
	health = max_health
	$Hurtbox.set_meta("owner_character", self)
	weapons.owner_character = self
	if weapons.current: weapons.current.set_meta("owner_character", self)
	rig.pose(0, state, velocity, 0, 0)
	_sync_visual(0)

## Shared input seam: AI / NPC controllers use this without modifying the rig.
func set_intent(direction: float, jump := false, attack := false) -> void:
	move_intent = clampf(direction, -1, 1)
	jump_requested = jump_requested or jump
	attack_requested = attack_requested or attack

func transition(next: StringName) -> void:
	if state == next: return
	var previous := state
	state = next
	state_changed.emit(previous, state)

func _physics_process(delta: float) -> void:
	if player_controlled:
		var input_direction := Input.get_axis("move_left", "move_right")
		if Input.is_action_pressed("walk"): input_direction *= walk_speed_ratio
		set_intent(input_direction, Input.is_action_just_pressed("jump"), Input.is_action_just_pressed("attack"))
		if Input.is_action_just_pressed("equipment"): equipment.toggle()
		if Input.is_action_just_pressed("weapon_sword"): weapons.equip(weapons.default_weapon)
		if Input.is_action_just_pressed("weapon_none"): weapons.equip(null)
		if Input.is_action_just_pressed("debug_rig"): rig.debug_draw = not rig.debug_draw
	var grounded := is_on_floor()
	velocity.x = move_toward(velocity.x, move_intent * move_speed * (0.35 if state == &"Attack" else 1.0), acceleration * delta)
	if move_intent != 0 and state != &"Attack": facing = signf(move_intent)
	if not grounded: velocity.y += gravity * delta
	if jump_requested and grounded: velocity.y = jump_velocity
	if attack_requested and state != &"Attack" and (grounded or allow_air_attack):
		attack_time = 0
		transition(&"Attack")
		if weapons.current: weapons.current.begin_attack()
	jump_requested = false
	attack_requested = false
	move_and_slide()
	land_time = maxf(0, land_time - delta)
	if not grounded and is_on_floor(): land_time = 0.14
	if state == &"Attack":
		attack_time += delta
		if attack_time >= attack_duration: transition(&"Idle")
	if state != &"Attack":
		if not is_on_floor(): transition(&"Jump" if velocity.y < 0 else &"Fall")
		elif absf(velocity.x) <= 5: transition(&"Idle")
		else: transition(&"Walk" if absf(velocity.x) <= move_speed * 0.6 else &"Run")
	rig.pose(delta, state, Vector2(velocity.x * facing, velocity.y), attack_time, land_time)
	_sync_visual(delta)

func _sync_visual(delta: float) -> void:
	# Only the visual origin is snapped, never the physics body or FK anchors.
	visual.position = global_position.round() - global_position
	visual.scale.x = facing
	body_renderer.sync(rig)
	eyes.sync(rig, delta, absf(move_intent))
	equipment.sync(rig)
	weapons.sync(rig, attack_time, state == &"Attack")

func receive_hit(amount: float) -> void:
	health = maxf(health - amount, 0)
	damaged.emit(amount)
	# Full hurt/death states are an intentional post-MVP extension.
