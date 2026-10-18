class_name Angel
extends CharacterBody3D
## Base de los Ángeles: AT Field que absorbe el daño hasta romperse (por golpes,
## parry o neutralización con el AT Field del Eva), núcleo expuesto que recibe
## daño multiplicado, aturdimiento por parry, derrota y reaparición.
## Cada Ángel concreto implementa _build_model() y _think().

signal defeated

enum State { IDLE, WINDUP, ACTIVE, RECOVER, STAGGER, DEFEATED }

const EVA_MASK := 2
const AT_COLOR := Color(1.0, 0.55, 0.1, 0.0)

@export var display_name := "ÁNGEL"

@export_group("Aguante")
@export var max_health := 300.0
@export var max_at := 100.0
@export var at_regen := 20.0                ## por segundo
@export var at_regen_delay := 2.0
@export var broken_time := 5.0              ## segundos con el núcleo expuesto
@export var core_multiplier := 2.0
@export var respawn_time := 4.0

@export_group("Neutralización")
@export var neutralize_range := 80.0
@export var neutralize_rate := 30.0         ## AT por segundo con tu AT Field levantado cerca

@export_group("Parry")
@export var parry_at_damage := 60.0
@export var parry_stagger := 1.5

@export_group("Movimiento")
@export var turn_speed_deg := 120.0
@export var attacks_enabled := true

var state := State.IDLE
var health := max_health
var at := max_at
var broken := false
var parried_count := 0

var _state_time := 0.0
var _broken_left := 0.0
var _since_at_hit := 99.0
var _eva: EvaController
var _query_shape := SphereShape3D.new()
var _model: Node3D
var _body_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _at_mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = 16   # capa 5: enemigos
	add_to_group("enemigos")
	health = max_health
	at = max_at
	_model = Node3D.new()
	add_child(_model)
	_build_model()
	_reset()


func _physics_process(delta: float) -> void:
	if not _eva:
		_eva = get_tree().get_first_node_in_group("eva") as EvaController
	_state_time += delta
	_since_at_hit += delta

	if state == State.DEFEATED:
		if _state_time >= respawn_time:
			_reset()
		return

	_update_at_field(delta)
	if state == State.STAGGER:
		if _state_time >= parry_stagger:
			_set_state(State.IDLE)
	else:
		_think(delta)
	_update_visuals(delta)


# --- Para cada Ángel -------------------------------------------------------

## Crea colisión y mallas. Debe asignar _body_mat y _core_mat.
func _build_model() -> void:
	pass


## IA y ataques (no se llama aturdido ni derrotado).
func _think(_delta: float) -> void:
	pass


## Reinicia el estado propio del Ángel (se llama al aparecer y reaparecer).
func _on_reset() -> void:
	pass


## true si un golpe fuerte en este momento interrumpe su ataque.
func _interruptible() -> bool:
	return state == State.WINDUP


## Brillo del cuerpo según lo que esté haciendo.
func _body_glow() -> Color:
	if state == State.STAGGER:
		return Color(0.6, 0.6, 1.0) * 0.5
	return Color.BLACK


# --- Daño -----------------------------------------------------------------

func receive_hit(info: HitInfo) -> HitInfo.Result:
	if state == State.DEFEATED:
		return HitInfo.Result.BLOCKED
	if not broken:
		_damage_at(info.at_damage)
		_flash_at(0.7)
		return HitInfo.Result.AT_FIELD

	health = maxf(health - info.damage * core_multiplier, 0.0)
	_body_mat.emission = Color(1, 1, 1)
	if health <= 0.0:
		_set_state(State.DEFEATED)
		_on_defeated()
		defeated.emit()
	elif _interruptible() and info.stagger >= 0.5:
		_set_state(State.STAGGER)  # un golpe fuerte con el núcleo expuesto interrumpe su ataque
	return HitInfo.Result.HIT


## Golpea al Eva si está dentro de la esfera. Devuelve el resultado o -1 si no le dio.
func _hit_sphere(center: Vector3, radius: float, damage: float, knockback: Vector3, stagger: float, unblockable := false) -> int:
	_query_shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _query_shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = EVA_MASK
	for hit in get_world_3d().direct_space_state.intersect_shape(params, 4):
		var target: Object = hit.collider
		if not target.has_method("receive_hit"):
			continue
		var info := HitInfo.new()
		info.attacker = self
		info.damage = damage
		info.knockback = knockback
		info.point = center
		info.hitstop = 0.1
		info.stagger = stagger
		info.unblockable = unblockable
		var result: HitInfo.Result = target.receive_hit(info)
		if result == HitInfo.Result.PARRIED:
			parried_count += 1
			_damage_at(parry_at_damage)
			_flash_at(1.0)
			_set_state(State.STAGGER)
		return result
	return -1


func _update_at_field(delta: float) -> void:
	if broken:
		_broken_left -= delta
		if _broken_left <= 0.0:
			broken = false
			at = max_at
			_since_at_hit = 0.0
		return
	var eva_guarding := _eva and _eva.combat and _eva.combat.state == EvaCombat.State.GUARD
	if eva_guarding and eva_distance() < neutralize_range:
		# Dos AT Fields en contacto se anulan.
		_damage_at(neutralize_rate * delta)
		_flash_at(0.35)
	elif _since_at_hit >= at_regen_delay:
		at = minf(at + at_regen * delta, max_at)


func _damage_at(amount: float) -> void:
	if broken:
		return
	at -= amount
	_since_at_hit = 0.0
	if at <= 0.0:
		at = 0.0
		broken = true
		_broken_left = broken_time


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _reset() -> void:
	health = max_health
	at = max_at
	broken = false
	_model.rotation_degrees = Vector3.ZERO
	_set_state(State.IDLE)
	_on_reset()


func _on_defeated() -> void:
	create_tween().tween_property(_model, "rotation_degrees:x", -80.0, 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# --- Utilidades -------------------------------------------------------------

func eva_distance() -> float:
	if not _eva:
		return INF
	var d := _eva.global_position - global_position
	return Vector2(d.x, d.z).length()


func _face_eva(delta: float) -> void:
	if not _eva:
		return
	var to := _eva.global_position - global_position
	var diff := wrapf(atan2(-to.x, -to.z) - rotation.y, -PI, PI)
	var step := deg_to_rad(turn_speed_deg) * delta
	rotation.y += clampf(diff, -step, step)


func _forward() -> Vector3:
	return -global_basis.z


# --- Presentación ---------------------------------------------------------

func _update_visuals(_delta: float) -> void:
	_body_mat.emission = _body_mat.emission.lerp(_body_glow(), 0.3)
	# Núcleo: apagado con el AT Field arriba, brillante y palpitante cuando está expuesto.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	_core_mat.emission = Color(1, 0.1, 0.05) * (1.5 + pulse * 2.0) if broken else Color(0.3, 0.02, 0.02)
	if _at_mat:
		_at_mat.albedo_color.a = move_toward(_at_mat.albedo_color.a, 0.0, 0.03)


func _flash_at(alpha: float) -> void:
	if _at_mat:
		_at_mat.albedo_color.a = maxf(_at_mat.albedo_color.a, alpha)


## Octógono naranja del AT Field delante del Ángel.
func _build_at_field(radius: float, pos: Vector3) -> void:
	_at_mat = StandardMaterial3D.new()
	_at_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_at_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_at_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_at_mat.albedo_color = AT_COLOR
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.5
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.material = _at_mat
	var mi := _add_mesh(mesh, pos)
	mi.rotation_degrees = Vector3(90, 0, 22.5)


func _add_collision_capsule(radius: float, height: float) -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	shape.shape = capsule
	shape.position.y = height * 0.5
	add_child(shape)


func _material(color: Color, emissive := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emissive:
		mat.emission_enabled = true
		mat.emission = Color.BLACK
	return mat


func _add_mesh(mesh: Mesh, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	(parent if parent else _model).add_child(mi)
	return mi


## Esfera roja que se expande y desaparece (impacto de un ataque).
func _spawn_shockwave(center: Vector3, radius: float, color := Color(1, 0.2, 0.1, 0.5)) -> void:
	var ring := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mat := _material(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	ring.mesh = mesh
	get_tree().root.add_child(ring)
	ring.global_position = center
	ring.scale = Vector3.ONE * 0.3
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE, 0.15)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(ring.queue_free)
