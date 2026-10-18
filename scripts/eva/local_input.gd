class_name LocalInput
extends Node
## Fuente de input del jugador local (teclado/ratón o mando).

@export var camera_rig: EvaCamera


func get_input() -> EvaInput:
	var input := EvaInput.new()
	input.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	input.camera_yaw = camera_rig.yaw if camera_rig else 0.0
	input.sprint = Input.is_action_pressed("sprint")
	input.jump = Input.is_action_just_pressed("jump")
	input.attack_light = Input.is_action_just_pressed("attack_light")
	input.attack_heavy = Input.is_action_just_pressed("attack_heavy")
	input.at_field = Input.is_action_pressed("at_field")
	return input
