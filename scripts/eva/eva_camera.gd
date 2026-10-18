class_name EvaCamera
extends Node3D
## Cámara en tercera persona sobre el hombro. Sigue al Eva con suavizado y
## tiembla con pisadas, aterrizajes y derribos.

@export var target: EvaController
@export var height := 30.0
@export var follow_smoothing := 14.0
@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 3.0     ## rad/s con el stick al máximo
@export var min_pitch_deg := -60.0
@export var max_pitch_deg := 35.0

@export_group("Temblor")
@export var max_shake_offset := 4.0          ## metros
@export var max_shake_angle_deg := 2.5
@export var trauma_decay := 2.2
@export var footstep_trauma := 0.35
@export var landing_trauma := 0.9
@export var smash_trauma := 0.8

var yaw := 0.0
var pitch := deg_to_rad(-12.0)
var _trauma := 0.0
var _noise := FastNoiseLite.new()
var _time := 0.0

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	# Se mueve en _process leyendo la posición interpolada del Eva, así que no se interpola a sí misma.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_noise.frequency = 1.0
	if target:
		global_position = target.global_position + Vector3.UP * height
		yaw = target.rotation.y
		_spring_arm.add_excluded_object(target.get_rid())
		target.footstep.connect(func(s: float) -> void: add_trauma(footstep_trauma * s))
		target.landed.connect(func(s: float) -> void: add_trauma(landing_trauma * s))
		target.smashed.connect(func(s: float) -> void: add_trauma(smash_trauma * s))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	yaw -= stick.x * stick_sensitivity * delta
	pitch -= stick.y * stick_sensitivity * delta
	pitch = clampf(pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	rotation = Vector3(pitch, yaw, 0.0)

	if target:
		var goal := target.get_global_transform_interpolated().origin + Vector3.UP * height
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_smoothing * delta))

	_apply_shake(delta)


func _apply_shake(delta: float) -> void:
	_time += delta
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	# trauma^1.5: los golpes pequeños se notan y los grandes sacuden de verdad.
	var shake := pow(_trauma, 1.5)
	var t := _time * 25.0
	_camera.h_offset = max_shake_offset * shake * _noise.get_noise_2d(t, 0.0)
	_camera.v_offset = max_shake_offset * shake * _noise.get_noise_2d(0.0, t)
	var angle := deg_to_rad(max_shake_angle_deg) * shake
	_camera.rotation = Vector3(
		angle * _noise.get_noise_2d(t, 50.0),
		angle * _noise.get_noise_2d(t, 100.0),
		angle * _noise.get_noise_2d(t, 150.0))
