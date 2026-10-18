class_name AngelDummy
extends Angel
## Ángel de prueba: no se mueve y cada pocos segundos carga un golpe
## telegrafiado para practicar el parry.

@export_group("Ataque")
@export var attack_interval := 3.0
@export var attack_range := 75.0
@export var windup := 0.9
@export var recover := 0.6
@export var attack_reach := 32.0
@export var attack_radius := 24.0
@export var attack_damage := 15.0
@export var attack_knockback := 45.0

var windup_left := 0.0
var _attack_timer := 0.0


func _build_model() -> void:
	display_name = "ÁNGEL DE PRUEBA"
	_add_collision_capsule(10.0, 46.0)
	_body_mat = _material(Color(0.12, 0.2, 0.14), true)
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 10.0
	body_mesh.height = 46.0
	body_mesh.material = _body_mat
	_add_mesh(body_mesh, Vector3(0, 23, 0))

	var mask_mesh := BoxMesh.new()
	mask_mesh.size = Vector3(8, 10, 3)
	mask_mesh.material = _material(Color(0.92, 0.9, 0.85))
	_add_mesh(mask_mesh, Vector3(0, 40, -8.5))

	_core_mat = _material(Color(0.6, 0.05, 0.05), true)
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 4.0
	core_mesh.height = 8.0
	core_mesh.material = _core_mat
	_add_mesh(core_mesh, Vector3(0, 26, -9))
	_build_at_field(26.0, Vector3(0, 24, -20))


func _on_reset() -> void:
	_attack_timer = attack_interval


func _think(delta: float) -> void:
	match state:
		State.IDLE:
			_face_eva(delta)
			_attack_timer -= delta
			if attacks_enabled and not broken and _attack_timer <= 0.0 and eva_distance() < attack_range:
				windup_left = windup
				_set_state(State.WINDUP)
		State.WINDUP:
			_face_eva(delta * 0.5)
			windup_left -= delta
			if windup_left <= 0.0:
				_strike()
		State.RECOVER:
			if _state_time >= recover:
				_attack_timer = attack_interval
				_set_state(State.IDLE)


func _strike() -> void:
	var center := global_position + _forward() * attack_reach + Vector3.UP * 20.0
	_spawn_shockwave(center, attack_radius)
	_set_state(State.RECOVER)
	_hit_sphere(center, attack_radius, attack_damage, _forward() * attack_knockback, 0.6)
	if state == State.STAGGER:
		_attack_timer = attack_interval


func _body_glow() -> Color:
	if state == State.WINDUP:
		return Color(1, 0.1, 0.05) * (1.0 - windup_left / windup) * 1.5
	return super()
