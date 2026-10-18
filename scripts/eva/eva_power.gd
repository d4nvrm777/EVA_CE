class_name EvaPower
extends Node
## Energía del Eva. Conectado a un enchufe tiene energía infinita pero el cable
## limita hasta dónde puede ir. Desconectado gasta la batería interna; si se
## acaba, el Eva se queda inactivo.

signal connected(socket: PowerSocket)
signal disconnected(cut: bool)       ## cut = el enemigo le cortó el cable
signal shut_down
signal restarted

enum State { CONNECTED, INTERNAL, PLUGGING, INACTIVE }

@export var cable_length := 300.0
@export var plug_range := 45.0            ## distancia al enchufe para poder conectarse
@export var plug_time := 0.8              ## segundos quieto mientras se conecta
@export var battery_capacity := 75.0      ## segundos a consumo normal
@export var sprint_drain := 2.0           ## multiplicadores de consumo
@export var guard_drain := 1.6
@export var attack_drain := 1.3
@export var cut_stagger := 0.6            ## golpes con este aturdimiento o más cortan el cable
@export var inactive_time := 6.0          ## prototipo: tras apagarse vuelve con batería de emergencia
@export var emergency_battery := 20.0
@export var start_connected := true

var state := State.INTERNAL
var battery := battery_capacity
var socket: PowerSocket

var _plug_left := 0.0
var _pending_socket: PowerSocket
var _inactive_left := 0.0

@onready var body: EvaController = get_parent()


func _ready() -> void:
	battery = battery_capacity
	if body.combat:
		body.combat.damaged.connect(_on_damaged)
	if start_connected:
		_connect_nearest.call_deferred(INF)


## false mientras el Eva no puede actuar (conectándose o sin energía).
func can_act() -> bool:
	return state == State.CONNECTED or state == State.INTERNAL


func simulate(input: EvaInput, combat_state: EvaCombat.State, delta: float) -> void:
	match state:
		State.CONNECTED:
			if input.cable:
				disconnect_cable(false)
		State.INTERNAL:
			var rate := 1.0
			if input.sprint and input.move.length() > 0.1:
				rate *= sprint_drain
			if combat_state == EvaCombat.State.GUARD:
				rate *= guard_drain
			elif combat_state == EvaCombat.State.ATTACK:
				rate *= attack_drain
			battery = maxf(battery - rate * delta, 0.0)
			if battery <= 0.0:
				state = State.INACTIVE
				_inactive_left = inactive_time
				shut_down.emit()
			elif input.cable:
				_try_plug()
		State.PLUGGING:
			_plug_left -= delta
			if _plug_left <= 0.0:
				_attach(_pending_socket)
		State.INACTIVE:
			_inactive_left -= delta
			if _inactive_left <= 0.0:
				battery = emergency_battery
				state = State.INTERNAL
				restarted.emit()


## Impide que el Eva se aleje más que la longitud del cable.
func apply_tether() -> void:
	if state != State.CONNECTED:
		return
	var anchor := socket.global_position
	var offset := body.global_position - anchor
	offset.y = 0.0
	var dist := offset.length()
	if dist <= cable_length:
		return
	var dir := offset / dist
	body.global_position -= dir * (dist - cable_length)
	var outward := body.velocity.dot(dir)
	if outward > 0.0:
		body.velocity -= dir * outward


func tension() -> float:
	if state != State.CONNECTED:
		return 0.0
	var d := body.global_position - socket.global_position
	return clampf(Vector2(d.x, d.z).length() / cable_length, 0.0, 1.0)


func disconnect_cable(cut: bool) -> void:
	if state != State.CONNECTED:
		return
	socket.set_in_use(false)
	socket = null
	state = State.INTERNAL
	disconnected.emit(cut)


func nearest_socket(max_dist: float) -> PowerSocket:
	var best: PowerSocket
	var best_dist := max_dist
	for s: PowerSocket in get_tree().get_nodes_in_group("enchufes"):
		var d := s.global_position - body.global_position
		var dist := Vector2(d.x, d.z).length()
		if dist < best_dist:
			best = s
			best_dist = dist
	return best


func _try_plug() -> void:
	var s := nearest_socket(plug_range)
	if not s:
		return
	_pending_socket = s
	_plug_left = plug_time
	state = State.PLUGGING


func _connect_nearest(max_dist: float) -> void:
	var s := nearest_socket(max_dist)
	if s:
		_attach(s)


func _attach(s: PowerSocket) -> void:
	socket = s
	socket.set_in_use(true)
	battery = battery_capacity
	state = State.CONNECTED
	connected.emit(socket)


func _on_damaged(info: HitInfo) -> void:
	if info.stagger >= cut_stagger:
		disconnect_cable(true)
