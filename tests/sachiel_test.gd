extends SceneTree
## Prueba sin ventana de Sachiel: se acerca, lanza, rayo, agarre, fase 2 y derrota.
## Uso: godot --headless --path . --script res://tests/sachiel_test.gd


class ScriptedInput extends LocalInput:
	var script_fn: Callable

	func get_input() -> EvaInput:
		var input := EvaInput.new()
		if script_fn.is_valid():
			script_fn.call(input)
		return input


const HOME := Vector3(0, 0, -160)

var eva: EvaController
var angel: AngelSachiel
var scripted := ScriptedInput.new()
var failures: Array[String] = []


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	eva = main.get_node("Eva")
	angel = main.get_node("Angel")
	eva.add_child(scripted)
	eva.input_source = scripted

	await _test_approach()
	await _test_lance()
	await _test_lance_parry()
	await _test_beam_hits_if_still()
	await _test_beam_dodge()
	await _test_beam_blocked()
	await _test_grab()
	await _test_phase2()
	await _test_defeat()

	for f in failures:
		print("  FALLO: ", f)
	print("SACHIEL TEST: ", "OK" if failures.is_empty() else "FALLO")
	quit(0 if failures.is_empty() else 1)


## Coloca a Sachiel en HOME mirando al Eva, que queda a `distance` metros al sur.
func _setup(distance: float, attacks := true, first_attack_in := 0.2) -> void:
	angel.global_position = HOME
	angel.rotation.y = PI
	angel._reset()
	angel.attacks_enabled = attacks
	angel._cooldown_left = first_attack_in
	eva.combat.health = eva.combat.max_health
	eva.combat._set_state(EvaCombat.State.FREE)
	eva.combat._stagger_time = 0.0
	eva.global_position = HOME + Vector3(0, 0, distance)
	eva.velocity = Vector3.ZERO
	eva.rotation.y = 0.0  # mirando al norte, hacia Sachiel
	scripted.script_fn = Callable()
	await physics_frame


func _run(seconds: float) -> void:
	for i in roundi(seconds * 60):
		await physics_frame


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  MAL  ") + what)
	if not cond:
		failures.append(what)


func _hurt() -> bool:
	return eva.combat.health < eva.combat.max_health


func _test_approach() -> void:
	print("Acercamiento:")
	await _setup(150.0, false)
	await _run(8.0)
	var d := angel.eva_distance()
	_check(d <= angel.engage_distance + 2.0, "camina hasta el Eva (queda a %.0f m)" % d)


func _test_lance() -> void:
	print("Lanza de energía:")
	await _setup(40.0)
	await _run(0.3)
	_check(angel.attack == AngelSachiel.Attack.LANCE, "de cerca elige la lanza")
	await _run(1.2)
	_check(_hurt(), "la lanza hace daño sin defenderse")


func _test_lance_parry() -> void:
	print("Parry a la lanza:")
	await _setup(40.0)
	scripted.script_fn = func(input: EvaInput) -> void:
		input.at_field = angel.state == Angel.State.WINDUP and angel.windup_left < 0.12
	await _run(1.2)
	_check(angel.parried_count >= 1 and not _hurt(), "la lanza se puede parar con parry")
	_check(angel.state == Angel.State.STAGGER, "el parry lo deja aturdido")


func _test_beam_hits_if_still() -> void:
	print("Rayo ocular:")
	await _setup(120.0)
	await _run(0.3)
	_check(angel.attack == AngelSachiel.Attack.BEAM, "de lejos elige el rayo")
	await _run(2.0)
	_check(_hurt(), "el rayo da si te quedas quieto")


func _test_beam_dodge() -> void:
	await _setup(120.0)
	scripted.script_fn = func(input: EvaInput) -> void:
		# Espera a que la marca se fije y entonces sale corriendo hacia un lado.
		var locked := angel.attack == AngelSachiel.Attack.BEAM and angel.windup_left <= angel.beam_lock_time
		if locked:
			input.move = Vector2(1, 0)
			input.sprint = true
	await _run(2.0)
	_check(not _hurt(), "corriendo cuando se fija la marca se esquiva")


func _test_beam_blocked() -> void:
	await _setup(120.0)
	var blocked := [false]
	var on_guard := func(_r: HitInfo.Result) -> void: blocked[0] = true
	eva.combat.guarded.connect(on_guard)
	scripted.script_fn = func(input: EvaInput) -> void:
		input.at_field = angel.attack == AngelSachiel.Attack.BEAM and angel.windup_left < 0.6
	await _run(2.0)
	eva.combat.guarded.disconnect(on_guard)
	_check(blocked[0] and not _hurt(), "el AT Field mirando al Ángel bloquea el rayo")


func _test_grab() -> void:
	print("Agarre:")
	await _setup(40.0, true, 99.0)
	scripted.script_fn = func(input: EvaInput) -> void: input.at_field = true
	await _run(1.2)
	angel._cooldown_left = 0.0
	await _run(0.1)
	_check(angel.attack == AngelSachiel.Attack.GRAB, "si te cubres mucho de cerca, agarra")
	await _run(1.0)
	_check(_hurt(), "el agarre atraviesa el AT Field")


func _test_phase2() -> void:
	print("Fase 2:")
	await _setup(40.0, true, 99.0)
	angel.health = angel.max_health * 0.4
	await _run(0.1)
	angel._cooldown_left = 0.0
	await _run(0.05)
	_check(angel.phase2, "por debajo del 50 % entra en fase 2")
	_check(angel.windup_left < angel.lance_windup * 0.8, "en fase 2 carga más rápido (%.2f s)" % angel.windup_left)


func _test_defeat() -> void:
	print("Derrota:")
	await _setup(40.0, false)
	angel._damage_at(angel.max_at)
	var info := HitInfo.new()
	info.attacker = eva
	info.damage = angel.max_health
	angel.receive_hit(info)
	await _run(0.1)
	var crosses := 0
	for n in root.get_children():
		if n is CrossExplosion:
			crosses += 1
	_check(angel.state == Angel.State.DEFEATED, "con la vida a 0 cae")
	_check(crosses >= 1, "explota en cruz")
	await _run(angel.respawn_time + 0.2)
	_check(angel.state != Angel.State.DEFEATED and angel.health == angel.max_health, "reaparece")
