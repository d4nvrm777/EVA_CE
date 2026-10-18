extends SceneTree
## Prueba sin ventana del cable umbilical, la batería y la sincronización.
## Uso: godot --headless --path . --script res://tests/power_test.gd


class ScriptedInput extends LocalInput:
	var script_fn: Callable

	func get_input() -> EvaInput:
		var input := EvaInput.new()
		if script_fn.is_valid():
			script_fn.call(input)
		return input


var eva: EvaController
var angel: AngelDummy
var power: EvaPower
var scripted := ScriptedInput.new()
var failures: Array[String] = []


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	# Estas pruebas usan el Ángel de prueba en lugar de Sachiel.
	var sachiel := main.get_node("Angel")
	main.remove_child(sachiel)
	sachiel.free()
	angel = load("res://scenes/angel_dummy.tscn").instantiate()
	angel.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -70))
	main.add_child(angel)
	main.get_node("HUD/CombatHUD").angel = angel
	root.add_child(main)
	await process_frame
	await physics_frame
	eva = main.get_node("Eva")
	angel.attacks_enabled = false
	power = eva.power
	eva.add_child(scripted)
	eva.input_source = scripted

	await _test_starts_connected()
	await _test_tether()
	await _test_battery_drain()
	await _test_reconnect()
	await _test_shutdown()
	await _test_cable_cut()
	await _test_sync()

	for f in failures:
		print("  FALLO: ", f)
	print("POWER TEST: ", "OK" if failures.is_empty() else "FALLO")
	quit(0 if failures.is_empty() else 1)


func _run(seconds: float) -> void:
	for i in roundi(seconds * 60):
		await physics_frame


func _press_once(field: String) -> void:
	var pressed := [false]
	scripted.script_fn = func(input: EvaInput) -> void:
		if not pressed[0]:
			input.set(field, true)
			pressed[0] = true
	await _run(0.1)
	scripted.script_fn = Callable()


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  MAL  ") + what)
	if not cond:
		failures.append(what)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _test_starts_connected() -> void:
	print("Inicio:")
	_check(power.state == EvaPower.State.CONNECTED, "empieza conectado al enchufe de la plaza")
	var before := power.battery
	await _run(2.0)
	_check(power.battery == before, "conectado no gasta batería")


func _test_tether() -> void:
	print("Cable:")
	# Corre en línea recta lejos del enchufe durante 10 s.
	eva.global_position = power.socket.global_position + Vector3(20, 0, 0)
	eva.rotation.y = -PI / 2.0
	scripted.script_fn = func(input: EvaInput) -> void:
		input.move = Vector2(0, -1)
		input.camera_yaw = -PI / 2.0
		input.sprint = true
	await _run(10.0)
	scripted.script_fn = Callable()
	var dist := _flat_dist(eva.global_position, power.socket.global_position)
	_check(dist <= power.cable_length + 1.0, "el cable no deja pasar de %d m (a %.0f m)" % [power.cable_length, dist])
	_check(dist >= power.cable_length - 20.0, "pero sí llega hasta el límite")


func _test_battery_drain() -> void:
	print("Batería interna:")
	await _press_once("cable")
	_check(power.state == EvaPower.State.INTERNAL, "E suelta el cable")
	var before := power.battery
	await _run(2.0)
	var idle_rate := (before - power.battery) / 2.0
	before = power.battery
	scripted.script_fn = func(input: EvaInput) -> void:
		input.move = Vector2(0, -1)
		input.sprint = true
	await _run(2.0)
	scripted.script_fn = Callable()
	var sprint_rate := (before - power.battery) / 2.0
	_check(absf(idle_rate - 1.0) < 0.05, "quieto gasta 1 s de batería por segundo (%.2f)" % idle_rate)
	_check(sprint_rate > idle_rate * 1.8, "corriendo gasta el doble (%.2f)" % sprint_rate)


func _test_reconnect() -> void:
	print("Reconectar:")
	var socket := power.nearest_socket(INF)
	eva.global_position = socket.global_position + Vector3(25, 0, 0)
	eva.velocity = Vector3.ZERO
	await _press_once("cable")
	_check(power.state == EvaPower.State.PLUGGING, "cerca de un enchufe, E empieza a conectar")
	await _run(1.0)
	_check(power.state == EvaPower.State.CONNECTED, "tras %.1f s queda conectado" % power.plug_time)
	_check(power.battery == power.battery_capacity, "la batería se recarga al conectar")
	var far := power.socket.global_position + Vector3(150, 0, 0)
	await _press_once("cable")
	eva.global_position = far
	await _press_once("cable")
	_check(power.state == EvaPower.State.INTERNAL, "lejos de un enchufe, E no hace nada")


func _test_shutdown() -> void:
	print("Sin energía:")
	power.battery = 0.5
	await _run(1.0)
	_check(power.state == EvaPower.State.INACTIVE, "con la batería a 0 se apaga")
	var pos := eva.global_position
	scripted.script_fn = func(input: EvaInput) -> void:
		input.move = Vector2(0, -1)
	await _run(1.0)
	scripted.script_fn = Callable()
	_check(_flat_dist(pos, eva.global_position) < 0.5, "apagado no responde al input")
	await _run(power.inactive_time)
	_check(power.state == EvaPower.State.INTERNAL and power.battery > 0.0, "vuelve con batería de emergencia")


func _test_cable_cut() -> void:
	print("Cable cortado:")
	eva.global_position = angel.global_position + Vector3(0, 0, 35)
	eva.velocity = Vector3.ZERO
	power._connect_nearest(INF)
	var cut := [false]
	power.disconnected.connect(func(was_cut: bool) -> void: cut[0] = was_cut, CONNECT_ONE_SHOT)
	angel.attacks_enabled = true
	angel._attack_timer = 0.1
	await _run(1.5)
	angel.attacks_enabled = false
	_check(cut[0] and power.state != EvaPower.State.CONNECTED, "un golpe del Ángel corta el cable")


func _test_sync() -> void:
	print("Sincronización:")
	angel._reset()
	eva.combat.health = eva.combat.max_health
	eva.combat._set_state(EvaCombat.State.FREE)
	eva.combat.sync = 50.0
	eva.global_position = angel.global_position + Vector3(0, 0, 35)
	var frame := [0]
	scripted.script_fn = func(input: EvaInput) -> void:
		frame[0] += 1
		input.attack_light = frame[0] % 6 == 0
	await _run(2.0)
	scripted.script_fn = Callable()
	_check(eva.combat.sync > 55.0, "golpear sube la sincronización (%.0f%%)" % eva.combat.sync)
	var high := eva.combat.damage_multiplier()
	eva.combat.sync = 10.0
	_check(high > eva.combat.damage_multiplier(), "más sincronización = más daño")
	var info := HitInfo.new()
	info.attacker = angel
	info.damage = 20.0
	eva.combat.sync = 60.0
	eva.combat.receive_hit(info)
	_check(eva.combat.sync < 60.0, "recibir daño baja la sincronización")
