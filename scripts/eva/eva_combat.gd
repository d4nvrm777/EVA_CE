class_name EvaCombat
extends Node
## Combate del Eva: ataques con cuchillo, AT Field defensivo/parry, vida y
## aturdimiento. Igual que el controlador, sólo lee EvaInput.

signal attack_started(attack: AttackData)
signal hit_landed(result: HitInfo.Result, info: HitInfo)
signal damaged(info: HitInfo)
signal guarded(result: HitInfo.Result)
signal state_changed(state: State)
signal health_changed(health: float, max_health: float)
signal sync_changed(sync: float)

enum State { FREE, ATTACK, GUARD, STAGGER, DOWN }

const LIGHT_COMBO: Array[AttackData] = [
	preload("res://data/attacks/light_1.tres"),
	preload("res://data/attacks/light_2.tres"),
	preload("res://data/attacks/light_3.tres"),
]
const HEAVY: AttackData = preload("res://data/attacks/heavy.tres")
const TARGET_MASK := 2 | 16   # eva, enemigos

@export var max_health := 100.0
@export var parry_window := 0.18           ## segundos tras levantar el AT Field
@export var parried_stagger := 1.0         ## aturdimiento propio si te hacen parry
@export var guard_knockback_scale := 0.3
@export var soft_lock_range := 70.0        ## al atacar, gira hacia el enemigo más cercano
@export var lunge_stop_distance := 30.0    ## el avance del golpe se detiene a esta distancia del objetivo
@export var down_time := 3.0               ## prototipo: tras caer, se recupera con la vida llena

@export_group("Sincronización")
@export var sync_start := 50.0             ## %
@export var sync_rest := 40.0              ## hacia donde vuelve sin combate
@export var sync_decay := 1.5              ## % por segundo hacia sync_rest
@export var sync_on_hit := 2.5
@export var sync_on_parry := 12.0
@export var sync_on_block := 1.0
@export var sync_per_damage := 0.8         ## % perdido por punto de daño recibido
@export var sync_damage_range := Vector2(0.6, 1.6)   ## multiplicador de daño a 0% y 100%
@export var sync_speed_range := Vector2(0.85, 1.15)  ## multiplicador de velocidad a 0% y 100%

var state := State.FREE
var health := max_health
var guard_time := 0.0
var attack: AttackData
var combo_index := -1
var pending_impulse := Vector3.ZERO        ## lo consume el controlador
var lock_target: Node3D                    ## objetivo del ataque actual (soft lock)
var sync := 50.0

var _attack_time := 0.0
var _buffered: AttackData
var _hit_targets: Array[RID] = []
var _hitstop := 0.0
var _stagger_time := 0.0
var _down_time := 0.0
var _query_shape := SphereShape3D.new()

@onready var body: CharacterBody3D = get_parent()


func _ready() -> void:
	health = max_health
	sync = sync_start


func damage_multiplier() -> float:
	return lerpf(sync_damage_range.x, sync_damage_range.y, sync / 100.0)


func add_sync(amount: float) -> void:
	sync = clampf(sync + amount, 0.0, 100.0)
	sync_changed.emit(sync)


func in_hitstop() -> bool:
	return _hitstop > 0.0


## Multiplicadores que aplica el controlador: x = velocidad, y = giro.
func movement_scale() -> Vector2:
	var speed := lerpf(sync_speed_range.x, sync_speed_range.y, sync / 100.0)
	match state:
		State.ATTACK: return Vector2(0.1, 0.25)
		State.GUARD: return Vector2(0.35, 0.6)
		State.STAGGER, State.DOWN: return Vector2.ZERO
	return Vector2(speed, 1.0)


## Avance automático durante el golpe (m/s), 0 si no hay.
func lunge_speed() -> float:
	if state == State.ATTACK and _attack_time < attack.startup + attack.active:
		if is_instance_valid(lock_target) and _flat_distance(lock_target) <= lunge_stop_distance:
			return 0.0
		return attack.lunge_speed
	return 0.0


func simulate(input: EvaInput, delta: float) -> void:
	sync = move_toward(sync, sync_rest, sync_decay * delta)
	if _hitstop > 0.0:
		_hitstop -= delta
		_buffer(input)
		return

	match state:
		State.FREE:
			if input.attack_light:
				_start_attack(LIGHT_COMBO[0], 0)
			elif input.attack_heavy:
				_start_attack(HEAVY, -1)
			elif input.at_field:
				_set_state(State.GUARD)
				guard_time = 0.0
		State.GUARD:
			guard_time += delta
			if input.attack_light:
				_start_attack(LIGHT_COMBO[0], 0)
			elif input.attack_heavy:
				_start_attack(HEAVY, -1)
			elif not input.at_field:
				_set_state(State.FREE)
		State.ATTACK:
			_attack_time += delta
			_buffer(input)
			if _attack_time >= attack.startup and _attack_time < attack.startup + attack.active:
				_query_hits()
			if _attack_time >= attack.startup + attack.active and _buffered:
				_start_attack(_buffered, combo_index + 1 if _buffered != HEAVY else -1)
			elif _attack_time >= attack.total_time():
				_set_state(State.FREE)
		State.STAGGER:
			_stagger_time -= delta
			if _stagger_time <= 0.0:
				_set_state(State.FREE)
		State.DOWN:
			_down_time -= delta
			if _down_time <= 0.0:
				health = max_health
				health_changed.emit(health, max_health)
				_set_state(State.FREE)


func receive_hit(info: HitInfo) -> HitInfo.Result:
	if state == State.DOWN:
		return HitInfo.Result.BLOCKED
	if state == State.GUARD and info.is_frontal(body):
		var result := HitInfo.Result.PARRIED if guard_time <= parry_window else HitInfo.Result.BLOCKED
		pending_impulse += info.knockback * guard_knockback_scale
		_hitstop = info.hitstop
		add_sync(sync_on_parry if result == HitInfo.Result.PARRIED else sync_on_block)
		guarded.emit(result)
		return result

	health = maxf(health - info.damage, 0.0)
	health_changed.emit(health, max_health)
	add_sync(-info.damage * sync_per_damage)
	pending_impulse += info.knockback
	_hitstop = info.hitstop
	if health <= 0.0:
		_down_time = down_time
		_set_state(State.DOWN)
	else:
		_stagger(info.stagger)
	damaged.emit(info)
	return HitInfo.Result.HIT


func on_parried() -> void:
	_stagger(parried_stagger)


func _stagger(duration: float) -> void:
	_stagger_time = maxf(_stagger_time, duration)
	_buffered = null
	_set_state(State.STAGGER)


func _buffer(input: EvaInput) -> void:
	if state != State.ATTACK:
		return
	if input.attack_heavy:
		_buffered = HEAVY
	elif input.attack_light and combo_index >= 0 and combo_index + 1 < LIGHT_COMBO.size():
		_buffered = LIGHT_COMBO[combo_index + 1]


func _start_attack(data: AttackData, index: int) -> void:
	attack = data
	combo_index = index
	_attack_time = 0.0
	_buffered = null
	_hit_targets.clear()
	_face_nearest_enemy()
	_set_state(State.ATTACK)
	attack_started.emit(data)


func _set_state(new_state: State) -> void:
	if state == new_state and new_state != State.ATTACK:
		return
	state = new_state
	state_changed.emit(state)


func _face_nearest_enemy() -> void:
	lock_target = null
	var best_dist := soft_lock_range
	for enemy: Node3D in get_tree().get_nodes_in_group("enemigos"):
		var dist := _flat_distance(enemy)
		if dist < best_dist:
			lock_target = enemy
			best_dist = dist
	if lock_target:
		var to := lock_target.global_position - body.global_position
		body.rotation.y = atan2(-to.x, -to.z)


func _flat_distance(node: Node3D) -> float:
	var d := node.global_position - body.global_position
	return Vector2(d.x, d.z).length()


func _query_hits() -> void:
	var forward := -body.global_basis.z
	var center := body.global_position + forward * attack.reach + Vector3.UP * attack.height
	_query_shape.radius = attack.radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _query_shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = TARGET_MASK
	params.exclude = [body.get_rid()]
	for hit in body.get_world_3d().direct_space_state.intersect_shape(params, 8):
		var target: Object = hit.collider
		var rid: RID = hit.rid
		if rid in _hit_targets or not target.has_method("receive_hit"):
			continue
		_hit_targets.append(rid)
		var info := HitInfo.new()
		info.attacker = body
		info.damage = attack.damage * damage_multiplier()
		info.at_damage = attack.at_damage
		info.knockback = forward * attack.knockback
		info.point = center
		info.hitstop = attack.hitstop
		info.stagger = attack.stagger
		var result: HitInfo.Result = target.receive_hit(info)
		if result == HitInfo.Result.PARRIED:
			on_parried()
		else:
			_hitstop = attack.hitstop
			add_sync(sync_on_hit)
		hit_landed.emit(result, info)
