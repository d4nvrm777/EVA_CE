extends SceneTree
## Prueba sin ventana del combate contra el Ángel de prueba.
## Uso: godot --headless --path . --script res://tests/combat_test.gd


class ScriptedInput extends LocalInput:
	var script_fn: Callable

	func get_input() -> EvaInput:
		var input := EvaInput.new()
		if script_fn.is_valid():
			script_fn.call(input)
		return input


var eva: EvaController
var angel: AngelDummy
var scripted := ScriptedInput.new()
var frame := 0
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
	eva = main.get_node("Eva")
	eva.add_child(scripted)
	eva.input_source = scripted

	await _test_combo_breaks_at_field()
	await _test_parry()
	await _test_unguarded_hit()
	await _test_late_guard_blocks()
	await _test_neutralization()

	for f in failures:
		print("  FALLO: ", f)
	print("COMBAT TEST: ", "OK" if failures.is_empty() else "FALLO")
	quit(0 if failures.is_empty() else 1)


func _setup(attacks: bool, first_attack_in := 99.0) -> void:
	angel._reset()
	angel.attacks_enabled = attacks
	angel._attack_timer = first_attack_in
	eva.combat.health = eva.combat.max_health
	eva.combat._set_state(EvaCombat.State.FREE)
	eva.global_position = angel.global_position + Vector3(0, 0, 35)
	eva.velocity = Vector3.ZERO
	eva.rotation.y = 0.0
	scripted.script_fn = Callable()
	await physics_frame


func _run(seconds: float) -> void:
	for i in roundi(seconds * 60):
		frame += 1
		await physics_frame


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  MAL  ") + what)
	if not cond:
		failures.append(what)


func _test_combo_breaks_at_field() -> void:
	print("Combo de cuchillo contra el AT Field:")
	await _setup(false)
	var results := {}
	var on_hit := func(r: HitInfo.Result, _i: HitInfo) -> void: results[r] = results.get(r, 0) + 1
	eva.combat.hit_landed.connect(on_hit)
	var was_broken := [false]
	scripted.script_fn = func(input: EvaInput) -> void:
		input.attack_light = frame % 6 == 0
		was_broken[0] = was_broken[0] or angel.broken
	await _run(6.0)
	eva.combat.hit_landed.disconnect(on_hit)
	print("    golpes: AT=%d núcleo=%d | vida ángel %.0f/%.0f" % [results.get(HitInfo.Result.AT_FIELD, 0), results.get(HitInfo.Result.HIT, 0), angel.health, angel.max_health])
	_check(results.get(HitInfo.Result.AT_FIELD, 0) >= 5, "los cortes golpean el AT Field")
	_check(was_broken[0], "el AT Field se rompe")
	_check(angel.health < angel.max_health, "con el AT Field roto el núcleo recibe daño")


func _test_parry() -> void:
	print("Parry:")
	await _setup(true, 0.3)
	scripted.script_fn = func(input: EvaInput) -> void:
		input.at_field = angel.state == Angel.State.WINDUP and angel.windup_left < 0.12
	await _run(2.0)
	_check(angel.parried_count >= 1, "levantar el AT Field justo antes del golpe hace parry")
	_check(eva.combat.health == eva.combat.max_health, "el parry no hace daño al Eva")
	_check(angel.at < angel.max_at, "el parry daña el AT Field del Ángel")


func _test_unguarded_hit() -> void:
	print("Golpe sin defenderse:")
	await _setup(true, 0.3)
	await _run(2.0)
	_check(eva.combat.health < eva.combat.max_health, "el golpe del Ángel hace daño")


func _test_late_guard_blocks() -> void:
	print("Bloqueo (AT Field levantado de antes):")
	await _setup(true, 0.6)
	var guarded := [0]
	var on_guard := func(r: HitInfo.Result) -> void:
		if r == HitInfo.Result.BLOCKED:
			guarded[0] += 1
	eva.combat.guarded.connect(on_guard)
	var parries_before := angel.parried_count
	scripted.script_fn = func(input: EvaInput) -> void: input.at_field = true
	await _run(2.5)
	eva.combat.guarded.disconnect(on_guard)
	_check(guarded[0] >= 1 and angel.parried_count == parries_before, "bloquea sin parry")
	_check(eva.combat.health == eva.combat.max_health, "el bloqueo no hace daño")


func _test_neutralization() -> void:
	print("Neutralización del AT Field:")
	await _setup(false)
	scripted.script_fn = func(input: EvaInput) -> void: input.at_field = true
	await _run(2.0)
	_check(angel.at <= angel.max_at - 50.0, "mantener el AT Field cerca neutraliza el del Ángel (AT %.0f)" % angel.at)
