class_name EvaController
extends CharacterBody3D
## Movimiento pesado en tercera persona. El Eva gira con velocidad limitada y
## sólo avanza hacia donde mira, así que cambiar de dirección cuesta tiempo.

signal footstep(strength: float)
signal landed(strength: float)
signal smashed(strength: float)

@export var input_source: LocalInput
@export var combat: EvaCombat
@export var power: EvaPower

@export_group("Velocidad")
@export var walk_speed := 32.0          ## m/s (el Eva mide ~40 m)
@export var sprint_speed := 65.0
@export var acceleration := 55.0        ## m/s²
@export var deceleration := 70.0
@export var turn_speed_deg := 420.0     ## grados por segundo

@export_group("Salto y gravedad")
@export var jump_velocity := 38.0
@export var gravity_scale := 6.0

@export_group("Pasos")
@export var stride_length := 22.0       ## metros entre pisadas

@export_group("Choques")
@export var building_break_speed := 25.0  ## velocidad mínima para derribar un edificio

var _stride_progress := 0.0
var _was_on_floor := true
var _last_fall_speed := 0.0
@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_scale


func _physics_process(delta: float) -> void:
	var input := input_source.get_input() if input_source else EvaInput.new()
	simulate(input, delta)


func simulate(input: EvaInput, delta: float) -> void:
	if power:
		power.simulate(input, combat.state if combat else EvaCombat.State.FREE, delta)
		if not power.can_act():
			input = EvaInput.new()  # conectándose o sin energía: no responde
	var scale := Vector2.ONE
	var lunge := 0.0
	var free := true  # sin atacar, bloquear ni aturdido: puede saltar y correr
	if combat:
		combat.simulate(input, delta)
		if combat.in_hitstop():
			return  # congelado unos frames para que el golpe pese
		scale = combat.movement_scale()
		free = combat.state == EvaCombat.State.FREE
		lunge = combat.lunge_speed()
		velocity += combat.pending_impulse
		combat.pending_impulse = Vector3.ZERO

	var on_floor := is_on_floor()

	if not on_floor:
		velocity.y -= _gravity * delta
		_last_fall_speed = -velocity.y
	elif input.jump and free:
		velocity.y = jump_velocity

	var move_strength := minf(input.move.length(), 1.0)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	if lunge > 0.0:
		horizontal = -global_basis.z * lunge
	elif move_strength > 0.0 and scale.x > 0.0:
		var wish_dir := Vector3(input.move.x, 0.0, input.move.y).rotated(Vector3.UP, input.camera_yaw).normalized()
		_turn_towards(wish_dir, delta * scale.y)
		# Avanza en la dirección que mira; si el input apunta detrás, frena en vez de patinar.
		var forward := -global_basis.z
		var alignment := clampf(forward.dot(wish_dir), 0.0, 1.0)
		var top_speed := (sprint_speed if input.sprint and free else walk_speed) * scale.x
		var target := forward * top_speed * move_strength * alignment
		horizontal = horizontal.move_toward(target, acceleration * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, deceleration * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var pre_slide_velocity := velocity
	move_and_slide()
	if power:
		power.apply_tether()

	_handle_impacts(pre_slide_velocity)
	_handle_footsteps(on_floor, horizontal.length(), delta)

	if is_on_floor() and not _was_on_floor:
		landed.emit(clampf(_last_fall_speed / 60.0, 0.2, 1.0))
	_was_on_floor = is_on_floor()


## Los golpes que recibe el cuerpo los gestiona el combate.
func receive_hit(info: HitInfo) -> HitInfo.Result:
	return combat.receive_hit(info) if combat else HitInfo.Result.HIT


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _turn_towards(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	var diff := wrapf(target_yaw - rotation.y, -PI, PI)
	var max_step := deg_to_rad(turn_speed_deg) * delta
	rotation.y += clampf(diff, -max_step, max_step)


func _handle_impacts(pre_slide_velocity: Vector3) -> void:
	var impact_speed := Vector2(pre_slide_velocity.x, pre_slide_velocity.z).length()
	if impact_speed < building_break_speed:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.has_method("take_impact") and collider.take_impact(pre_slide_velocity, collision.get_position()):
			smashed.emit(clampf(impact_speed / sprint_speed, 0.5, 1.0))
			# El choque no te frena del todo: atraviesas el edificio que se derrumba.
			velocity = pre_slide_velocity * 0.85


func _handle_footsteps(on_floor: bool, speed: float, delta: float) -> void:
	if not on_floor or speed < 1.0:
		_stride_progress = 0.0
		return
	_stride_progress += speed * delta
	if _stride_progress >= stride_length:
		_stride_progress -= stride_length
		footstep.emit(clampf(speed / sprint_speed, 0.3, 1.0))
