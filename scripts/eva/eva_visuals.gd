extends Node3D
## Presentación del Eva: cuchillo, AT Field, chispas de impacto y caída.
## Sólo escucha señales del combate; no cambia la lógica.

const AT_COLOR := Color(1.0, 0.55, 0.1, 0.35)

@export var combat: EvaCombat

var _knife_pivot: Node3D
var _at_field: MeshInstance3D
var _at_material: StandardMaterial3D
var _swing: Tween


func _ready() -> void:
	_build_knife()
	_build_at_field()
	combat.attack_started.connect(_on_attack_started)
	combat.state_changed.connect(_on_state_changed)
	combat.guarded.connect(_on_guarded)
	combat.hit_landed.connect(func(result: HitInfo.Result, info: HitInfo) -> void: HitSpark.spawn(self, info.point, result))
	combat.damaged.connect(func(info: HitInfo) -> void: HitSpark.spawn(self, info.point, HitInfo.Result.HIT))


func _build_knife() -> void:
	_knife_pivot = Node3D.new()
	_knife_pivot.position = Vector3(9, 28, -2)
	add_child(_knife_pivot)
	var blade := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 2.5, 16)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 0.6
	mesh.material = mat
	blade.mesh = mesh
	blade.position = Vector3(0, 0, -9)
	_knife_pivot.add_child(blade)
	_knife_pivot.rotation_degrees = Vector3(-60, 0, 0)  # en reposo, apuntando hacia abajo


func _build_at_field() -> void:
	_at_field = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 22.0
	mesh.bottom_radius = 22.0
	mesh.height = 0.5
	mesh.radial_segments = 8   # octógono, como en la serie
	mesh.rings = 1
	_at_material = StandardMaterial3D.new()
	_at_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_at_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_at_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_at_material.albedo_color = AT_COLOR
	mesh.material = _at_material
	_at_field.mesh = mesh
	_at_field.rotation_degrees = Vector3(90, 0, 22.5)
	_at_field.position = Vector3(0, 22, -16)
	_at_field.visible = false
	add_child(_at_field)


func _on_attack_started(attack: AttackData) -> void:
	if _swing:
		_swing.kill()
	_swing = create_tween()
	var strike := attack.startup + attack.active
	# Cada golpe del combo tiene su trayectoria: derecha a izquierda, izquierda a derecha, de arriba abajo, estocada.
	var from: Vector3
	var to: Vector3
	match combat.combo_index:
		0:
			from = Vector3(0, -80, 0)
			to = Vector3(0, 70, 0)
		1:
			from = Vector3(0, 70, 0)
			to = Vector3(0, -80, 0)
		2:
			from = Vector3(80, 0, 0)
			to = Vector3(-50, 0, 0)
		_:
			from = Vector3(0, 0, 0)
			to = Vector3(0, 0, 0)
	_knife_pivot.rotation_degrees = from
	_knife_pivot.position.z = 6.0 if combat.combo_index < 0 else -2.0
	_swing.set_parallel()
	_swing.tween_property(_knife_pivot, "rotation_degrees", to, strike).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if combat.combo_index < 0:
		_swing.tween_property(_knife_pivot, "position:z", -12.0, strike).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_swing.chain().tween_property(_knife_pivot, "rotation_degrees", Vector3(-60, 0, 0), attack.recovery)
	_swing.parallel().tween_property(_knife_pivot, "position:z", -2.0, attack.recovery)


func _on_state_changed(state: EvaCombat.State) -> void:
	_at_field.visible = state == EvaCombat.State.GUARD
	if state == EvaCombat.State.GUARD:
		_at_field.scale = Vector3(0.6, 1, 0.6)
		create_tween().tween_property(_at_field, "scale", Vector3.ONE, 0.08)
	var tilt := Vector3(80, 0, 0) if state == EvaCombat.State.DOWN else Vector3.ZERO
	create_tween().tween_property(self, "rotation_degrees", tilt, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _on_guarded(result: HitInfo.Result) -> void:
	var flash := Color(1.0, 0.95, 0.8, 0.9) if result == HitInfo.Result.PARRIED else Color(1.0, 0.6, 0.2, 0.6)
	_at_material.albedo_color = flash
	create_tween().tween_property(_at_material, "albedo_color", AT_COLOR, 0.25)
	if result == HitInfo.Result.PARRIED:
		_at_field.scale = Vector3(1.4, 1, 1.4)
		create_tween().tween_property(_at_field, "scale", Vector3.ONE, 0.2)
