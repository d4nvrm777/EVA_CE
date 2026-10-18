extends Label
## Info de depuración y controles.

@export var eva: EvaController


func _process(_delta: float) -> void:
	var speed := eva.horizontal_speed() if eva else 0.0
	text = "Velocidad: %5.1f m/s  (%3d km/h)\nFPS: %d\n\nWASD / stick: mover   Ratón / stick der.: cámara\nShift / L3: correr   Espacio / A: saltar\nClic izq. / X: corte (combo x3)   Clic der. / Y: estocada\nQ / LB: AT Field (levántalo justo antes del golpe = parry)   Tab / R3: fijar objetivo\nCorre contra un edificio para derribarlo   Esc: soltar ratón" % [
		speed, roundi(speed * 3.6), Engine.get_frames_per_second()]
