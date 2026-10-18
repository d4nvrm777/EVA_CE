class_name AngelSachiel
extends Angel
## Primer Ángel "de verdad", inspirado en Sachiel. Se acerca andando y elige
## entre tres ataques según la distancia y lo que hagas:
## - Lanza de energía (cerca): estocada rápida del brazo. Se puede hacer parry.
## - Rayo ocular (lejos): marca el suelo bajo el Eva, la fija y explota en cruz.
##   Corriendo te da tiempo a salir; el AT Field mirando al Ángel lo bloquea.
## - Agarre (si te cubres demasiado de cerca): el AT Field no lo para, hay que
##   apartarse.
## Por debajo del 50 % de vida entra en fase 2: carga y encadena más rápido.

enum Attack { NONE, LANCE, BEAM, GRAB }

@export_group("Movimiento")
@export var walk_speed := 16.0
@export var engage_distance := 45.0          ## se acerca hasta esta distancia

@export_group("Ritmo")
@export var cooldown := 1.6
@export var phase2_speedup := 0.7            ## multiplica cargas y esperas en fase 2

@export_group("Lanza de energía")
@export var lance_range := 60.0
@export var lance_windup := 0.7
@export var lance_reach := 40.0
@export var lance_radius := 12.0
@export var lance_damage := 18.0

@export_group("Rayo ocular")
@export var beam_range := Vector2(60.0, 260.0)
@export var beam_windup := 1.5
@export var beam_lock_time := 1.1            ## la marca deja de seguirte este tiempo antes de explotar
@export var beam_radius := 20.0
@export var beam_damage := 25.0
@export var beam_building_radius := 35.0

@export_group("Agarre")
@export var grab_guard_time := 1.0           ## tiempo cubriéndote cerca para que te agarre
@export var grab_range := 55.0
@export var grab_windup := 0.6
@export var grab_damage := 22.0

var attack := Attack.NONE
var windup_left := 0.0
var phase2 := false

var _cooldown_left := 0.0
var _eva_guard_time := 0.0
var _beam_target := Vector3.ZERO
var _beam_marker: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _right_arm: Node3D
var _lance_mesh: MeshInstance3D


func _build_model() -> void:
	display_name = "SACHIEL"
	max_health = 400.0
	max_at = 120.0
	broken_time = 4.5
	collision_mask = 1 | 2 | 8
	_add_collision_capsule(10.0, 56.0)

	_body_mat = _material(Color(0.1, 0.22, 0.14), true)
	var bone := _material(Color(0.9, 0.88, 0.82))

	var torso := CapsuleMesh.new()
	torso.radius = 8.0
	torso.height = 30.0
	torso.material = _body_mat
	_add_mesh(torso, Vector3(0, 34, 0))
	var leg := CapsuleMesh.new()
	leg.radius = 3.5
	leg.height = 26.0
	leg.material = _body_mat
	_add_mesh(leg, Vector3(-4.5, 13, 0))
	_add_mesh(leg, Vector3(4.5, 13, 0))

	var arm := CapsuleMesh.new()
	arm.radius = 2.5
	arm.height = 28.0
	arm.material = _body_mat
	_add_mesh(arm, Vector3(-11, 32, 0))
	# El brazo derecho cuelga de un pivote en el hombro para poder lanzar la estocada.
	_right_arm = Node3D.new()
	_right_arm.position = Vector3(11, 44, 0)
	_model.add_child(_right_arm)
	_add_mesh(arm, Vector3(0, -12, 0), _right_arm)
	var lance := BoxMesh.new()
	lance.size = Vector3(1.5, lance_reach, 1.5)
	var lance_mat := _material(Color(0.8, 0.95, 1.0))
	lance_mat.emission_enabled = true
	lance_mat.emission = Color(0.6, 0.9, 1.0)
	lance_mat.emission_energy_multiplier = 3.0
	lance.material = lance_mat
	_lance_mesh = _add_mesh(lance, Vector3(0, -24 - lance_reach * 0.5, 0), _right_arm)  # sale de la mano siguiendo el brazo
	_lance_mesh.visible = false

	var shoulder := BoxMesh.new()
	shoulder.size = Vector3(6, 3, 5)
	shoulder.material = bone
	_add_mesh(shoulder, Vector3(-9, 47, 0))
	_add_mesh(shoulder, Vector3(9, 47, 0))

	# Máscara blanca de pájaro con dos ojos que brillan al cargar el rayo.
	var mask := PrismMesh.new()
	mask.size = Vector3(10, 12, 4)
	mask.material = bone
	var mask_mi := _add_mesh(mask, Vector3(0, 52, -6))
	mask_mi.rotation_degrees.x = 180.0
	_eye_mat = _material(Color(0.05, 0.05, 0.05), true)
	var eye := BoxMesh.new()
	eye.size = Vector3(2.2, 2.2, 1)
	eye.material = _eye_mat
	_add_mesh(eye, Vector3(-2.2, 53.5, -8.3))
	_add_mesh(eye, Vector3(2.2, 53.5, -8.3))

	var ribs := BoxMesh.new()
	ribs.size = Vector3(12, 2, 3)
	ribs.material = bone
	_add_mesh(ribs, Vector3(0, 40, -7))
	_add_mesh(ribs, Vector3(0, 28, -7))

	_core_mat = _material(Color(0.6, 0.05, 0.05), true)
	var core := SphereMesh.new()
	core.radius = 4.5
	core.height = 9.0
	core.material = _core_mat
	_add_mesh(core, Vector3(0, 34, -7.5))
	_build_at_field(30.0, Vector3(0, 30, -22))

	_beam_mat = _material(Color(1, 0.15, 0.1, 0.0))
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var marker := CylinderMesh.new()
	marker.top_radius = beam_radius
	marker.bottom_radius = beam_radius
	marker.height = 0.4
	marker.material = _beam_mat
	_beam_marker = MeshInstance3D.new()
	_beam_marker.mesh = marker
	_beam_marker.top_level = true
	_beam_marker.visible = false
	add_child(_beam_marker)


func _on_reset() -> void:
	attack = Attack.NONE
	phase2 = false
	_cooldown_left = cooldown
	_beam_marker.visible = false
	_lance_mesh.visible = false
	_right_arm.rotation_degrees = Vector3.ZERO


func _speed() -> float:
	return phase2_speedup if phase2 else 1.0


func _think(delta: float) -> void:
	if not phase2 and health < max_health * 0.5:
		phase2 = true
	var guarding := _eva and _eva.combat and _eva.combat.state == EvaCombat.State.GUARD
	_eva_guard_time = _eva_guard_time + delta if guarding and eva_distance() < grab_range else 0.0

	match state:
		State.IDLE:
			_face_eva(delta)
			_walk(delta)
			_cooldown_left -= delta
			if attacks_enabled and _cooldown_left <= 0.0:
				_choose_attack()
		State.WINDUP:
			_face_eva(delta * (0.3 if attack == Attack.LANCE else 1.0))
			windup_left -= delta
			if attack == Attack.BEAM and windup_left > beam_lock_time and _eva:
				_beam_target = _eva.global_position
			if windup_left <= 0.0:
				_release()
		State.ACTIVE:
			if _state_time >= 0.15:
				_lance_mesh.visible = false
				_set_state(State.RECOVER)
		State.RECOVER:
			_right_arm.rotation_degrees = _right_arm.rotation_degrees.lerp(Vector3.ZERO, 0.1)
			if _state_time >= 0.7 * _speed():
				_cooldown_left = cooldown * _speed()
				attack = Attack.NONE
				_set_state(State.IDLE)

	if attack == Attack.BEAM and state == State.WINDUP:
		_beam_marker.visible = true
		_beam_marker.global_position = _beam_target + Vector3.UP * 0.5
		var locked := windup_left <= beam_lock_time
		_beam_mat.albedo_color.a = 0.6 if locked else 0.25 + 0.15 * sin(Time.get_ticks_msec() * 0.02)
	else:
		_beam_marker.visible = false


## Ataque elegido según distancia y si el Eva se está cubriendo.
func _choose_attack() -> void:
	var dist := eva_distance()
	if _eva_guard_time >= grab_guard_time:
		_start(Attack.GRAB, grab_windup)
	elif dist < lance_range:
		_start(Attack.LANCE, lance_windup)
	elif dist >= beam_range.x and dist <= beam_range.y:
		_beam_target = _eva.global_position
		_start(Attack.BEAM, beam_windup)


func _start(kind: Attack, duration: float) -> void:
	attack = kind
	windup_left = duration * _speed()
	_set_state(State.WINDUP)
	if kind == Attack.LANCE:
		create_tween().tween_property(_right_arm, "rotation_degrees:x", -40.0, windup_left)  # echa el brazo atrás


func _release() -> void:
	match attack:
		Attack.LANCE:
			_right_arm.rotation_degrees = Vector3(90, 0, 0)  # brazo al frente
			_lance_mesh.visible = true
			_set_state(State.ACTIVE)
			var center := global_position + _forward() * lance_reach + Vector3.UP * 30.0
			_hit_sphere(center, lance_radius, lance_damage, _forward() * 50.0, 0.7)
		Attack.BEAM:
			_set_state(State.RECOVER)
			_explode_cross(_beam_target)
		Attack.GRAB:
			_set_state(State.RECOVER)
			var center := global_position + _forward() * 30.0 + Vector3.UP * 25.0
			_spawn_shockwave(center, 18.0, Color(0.6, 0.2, 1.0, 0.5))
			_hit_sphere(center, 18.0, grab_damage, -_forward() * 30.0, 1.2, true)


func _explode_cross(pos: Vector3) -> void:
	CrossExplosion.spawn(self, pos, 90.0)
	var center := pos + Vector3.UP * 15.0
	var away := (_eva.global_position - pos) if _eva else Vector3.ZERO
	away.y = 0.0
	_hit_sphere(center, beam_radius, beam_damage, away.normalized() * 60.0 + Vector3.UP * 10.0, 0.8)
	# La explosión también tira los edificios de alrededor.
	_query_shape.radius = beam_building_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _query_shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = 8
	for hit in get_world_3d().direct_space_state.intersect_shape(params, 16):
		var building: Object = hit.collider
		if building.has_method("take_impact"):
			var push: Vector3 = (building.global_position - pos).normalized() * 40.0
			building.take_impact(push, pos)


func _walk(_delta: float) -> void:
	if eva_distance() <= engage_distance:
		velocity = Vector3.ZERO
		return
	velocity = _forward() * walk_speed
	velocity.y = 0.0
	move_and_slide()
	# Lo que tenga delante se derrumba a su paso.
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.has_method("take_impact"):
			collider.take_impact(_forward() * 30.0, global_position)
	global_position.y = 0.0



func _interruptible() -> bool:
	return state == State.WINDUP and attack != Attack.BEAM


func _on_defeated() -> void:
	super()
	_beam_marker.visible = false
	_lance_mesh.visible = false
	CrossExplosion.spawn(self, global_position, 180.0)


func _body_glow() -> Color:
	if state == State.WINDUP:
		var t := 1.0 - windup_left / maxf(_windup_total(), 0.01)
		match attack:
			Attack.LANCE: return Color(1, 0.1, 0.05) * t * 1.5
			Attack.GRAB: return Color(0.6, 0.2, 1.0) * t * 1.5
	if phase2:
		return Color(0.4, 0.05, 0.02) * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008))
	return super()


func _windup_total() -> float:
	match attack:
		Attack.LANCE: return lance_windup * _speed()
		Attack.BEAM: return beam_windup * _speed()
		Attack.GRAB: return grab_windup * _speed()
	return 1.0


func _update_visuals(delta: float) -> void:
	super(delta)
	var charging := state == State.WINDUP and attack == Attack.BEAM
	_eye_mat.emission = Color(1.0, 0.9, 0.6) * 4.0 if charging else Color.BLACK
