class_name EvaInput
extends RefCounted
## Snapshot de input de un frame. La lógica del Eva sólo lee esto, nunca Input
## directamente, para que el mismo código sirva para jugador local, IA o red.

var move := Vector2.ZERO        ## x = derecha, y = atrás (como Input.get_vector)
var camera_yaw := 0.0           ## yaw de la cámara: el movimiento es relativo a ella
var sprint := false
var jump := false
