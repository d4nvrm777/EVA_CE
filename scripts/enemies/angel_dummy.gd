class_name AngelDummy
extends StaticBody3D
## Ángel de prueba. Tiene AT Field que hay que romper (golpes, parry o
## neutralizándolo con tu propio AT Field de cerca) para poder dañar el núcleo.
## Ataca cada pocos segundos con un golpe telegrafiado para practicar el parry.

signal defeated

enum State { IDLE, WINDUP, RECOVER, STAGGER, DEFEATED }

const EVA_MASK := 2
const AT_COLOR := Color(1.0, 0.55, 0.1, 0.0)

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

@export_group("Ataque")
@export var attacks_enabled := true
@export var attack_interval := 3.0
@export var attack_range := 75.0
@export var windup := 0.9
@export var recover := 0.6
@export var attack_reach := 32.0
@export var attack_radius := 24.0
@export var attack_damage := 15.0
@export var attack_knockback := 45.0
@export var parry_at_damage := 60.0
@export var parry_stagger := 1.5
@export var turn_speed_deg := 120.0

var state := State.IDLE
var health := max_health
var at := max_at
var broken := false
var windup_left := 0.0
var parried_count := 0

var _attack_timer := 0.0
var _state_time := 0.0
var _broken_left := 0.0
var _since_at_hit := 99.0
var _eva: EvaController
var _query_shape := SphereShape3D.new()
var _body_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _at_mat: StandardMaterial3D
var _model: Node3D
var _at_visual: MeshInstance3D


func _ready() -> void:
	collision_layer = 16   # capa 5: enemigos
	collision_mask = 0
	add_to_group("enemigos")
	health = max_health
	at = max_at
	_attack_timer = attack_interval
	_build()


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

	match state:
		State.IDLE:
			_face_eva(delta)
			_attack_timer -= delta
			if attacks_enabled and not broken and _attack_timer <= 0.0 and _eva_distance() < attack_range:
				windup_left = windup
				_set_state(State.WINDUP)
		State.WINDUP:
			_face_eva(delta * 0.5)
			windup_left -= delta
			if windup_left <= 0.0:
				_strike()
				if state == State.WINDUP:
					_set_state(State.RECOVER)
		State.RECOVER:
			if _state_time >= recover:
				_attack_timer = attack_interval
				_set_state(State.IDLE)
		State.STAGGER:
			if _state_time >= parry_stagger:
				_attack_timer = attack_interval
				_set_state(State.IDLE)

	_update_visuals()


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
		create_tween().tween_property(_model, "rotation_degrees:x", -80.0, 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		defeated.emit()
	elif state == State.WINDUP and info.stagger >= 0.5:
		_set_state(State.STAGGER)  # un golpe fuerte con el núcleo expuesto interrumpe su ataque
	return HitInfo.Result.HIT


func _strike() -> void:
	var forward := -global_basis.z
	var center := global_position + forward * attack_reach + Vector3.UP * 20.0
	_query_shape.radius = attack_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _query_shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = EVA_MASK
	_spawn_shockwave(center)
	for hit in get_world_3d().direct_space_state.intersect_shape(params, 4):
		var target: Object = hit.collider
		if not target.has_method("receive_hit"):
			continue
		var info := HitInfo.new()
		info.attacker = self
		info.damage = attack_damage
		info.knockback = forward * attack_knockback
		info.point = center
		info.hitstop = 0.1
		info.stagger = 0.6
		if target.receive_hit(info) == HitInfo.Result.PARRIED:
			parried_count += 1
			_damage_at(parry_at_damage)
			_flash_at(1.0)
			_set_state(State.STAGGER)


func _update_at_field(delta: float) -> void:
	if broken:
		_broken_left -= delta
		if _broken_left <= 0.0:
			broken = false
			at = max_at
			_since_at_hit = 0.0
		return
	var eva_guarding := _eva and _eva.combat and _eva.combat.state == EvaCombat.State.GUARD
	if eva_guarding and _eva_distance() < neutralize_range:
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
	_attack_timer = attack_interval
	_model.rotation_degrees = Vector3.ZERO
	_set_state(State.IDLE)


func _eva_distance() -> float:
	return _eva.global_position.distance_to(global_position) if _eva else INF


func _face_eva(delta: float) -> void:
	if not _eva:
		return
	var to := _eva.global_position - global_position
	var diff := wrapf(atan2(-to.x, -to.z) - rotation.y, -PI, PI)
	var step := deg_to_rad(turn_speed_deg) * delta
	rotation.y += clampf(diff, -step, step)


# --- Presentación ---------------------------------------------------------

func _build() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 10.0
	capsule.height = 46.0
	shape.shape = capsule
	shape.position.y = 23.0
	add_child(shape)

	_model = Node3D.new()
	add_child(_model)
	_body_mat = _material(Color(0.12, 0.2, 0.14))
	_body_mat.emission_enabled = true
	_body_mat.emission = Color.BLACK
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 10.0
	body_mesh.height = 46.0
	body_mesh.material = _body_mat
	_add_mesh(body_mesh, Vector3(0, 23, 0))

	var mask_mesh := BoxMesh.new()
	mask_mesh.size = Vector3(8, 10, 3)
	mask_mesh.material = _material(Color(0.92, 0.9, 0.85))
	_add_mesh(mask_mesh, Vector3(0, 40, -8.5))

	_core_mat = _material(Color(0.6, 0.05, 0.05))
	_core_mat.emission_enabled = true
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 4.0
	core_mesh.height = 8.0
	core_mesh.material = _core_mat
	_add_mesh(core_mesh, Vector3(0, 26, -9))

	_at_mat = StandardMaterial3D.new()
	_at_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_at_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_at_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_at_mat.albedo_color = AT_COLOR
	var at_mesh := CylinderMesh.new()
	at_mesh.top_radius = 26.0
	at_mesh.bottom_radius = 26.0
	at_mesh.height = 0.5
	at_mesh.radial_segments = 8
	at_mesh.rings = 1
	at_mesh.material = _at_mat
	_at_visual = _add_mesh(at_mesh, Vector3(0, 24, -20))
	_at_visual.rotation_degrees = Vector3(90, 0, 22.5)


func _update_visuals() -> void:
	# Telegrafía el ataque: el cuerpo se pone rojo durante la carga.
	var glow := Color.BLACK
	if state == State.WINDUP:
		glow = Color(1, 0.1, 0.05) * (1.0 - windup_left / windup) * 1.5
	elif state == State.STAGGER:
		glow = Color(0.6, 0.6, 1.0) * 0.5
	_body_mat.emission = _body_mat.emission.lerp(glow, 0.3)
	# Núcleo: apagado con el AT Field arriba, brillante y palpitante cuando está expuesto.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	_core_mat.emission = Color(1, 0.1, 0.05) * (1.5 + pulse * 2.0) if broken else Color(0.3, 0.02, 0.02)
	_at_mat.albedo_color.a = move_toward(_at_mat.albedo_color.a, 0.0, 0.03)


func _flash_at(alpha: float) -> void:
	_at_mat.albedo_color.a = maxf(_at_mat.albedo_color.a, alpha)


func _spawn_shockwave(center: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = attack_radius
	mesh.height = attack_radius * 2.0
	var mat := _material(Color(1, 0.2, 0.1, 0.5))
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


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _add_mesh(mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	_model.add_child(mi)
	return mi
