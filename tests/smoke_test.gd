extends SceneTree
## Prueba rápida sin ventana: el Eva corre contra un edificio y debe derribarlo.
## Uso: godot --headless --path . --script res://tests/smoke_test.gd


class ScriptedInput extends LocalInput:
	func get_input() -> EvaInput:
		var input := EvaInput.new()
		input.move = Vector2(0, -1)
		input.sprint = true
		return input


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var eva: EvaController = main.get_node("Eva")
	var city: Node3D = main.get_node("City")
	# Primer edificio al norte de la plaza central: hay pista libre para coger velocidad.
	var target: Building
	for b in city.get_children():
		if b is Building and absf(b.position.x) < 50.0 and b.position.z < 0.0 and (target == null or b.position.z > target.position.z):
			target = b
	eva.power.disconnect_cable(false)  # sin cable para poder correr lejos
	eva.global_position = Vector3(target.position.x, 0, 0)
	var scripted := ScriptedInput.new()
	eva.add_child(scripted)
	eva.input_source = scripted

	var buildings_before := _count_buildings(city)
	var steps := [0]  # array: las lambdas capturan locales por valor
	eva.footstep.connect(func(_s: float) -> void: steps[0] += 1)
	var start := eva.global_position

	for i in 60 * 12:
		await physics_frame

	var travelled := start.distance_to(eva.global_position)
	var destroyed := buildings_before - _count_buildings(city)
	print("recorrido: %.1f m | velocidad final: %.1f m/s | pisadas: %d | edificios derribados: %d" % [
		travelled, eva.horizontal_speed(), steps[0], destroyed])
	var ok: bool = travelled > 150.0 and steps[0] > 5 and destroyed >= 1
	print("SMOKE TEST: ", "OK" if ok else "FALLO")
	quit(0 if ok else 1)


func _count_buildings(city: Node) -> int:
	return city.get_children().filter(func(n: Node) -> bool: return n is Building).size()
