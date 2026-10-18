class_name Building
extends StaticBody3D
## Edificio placeholder. Al recibir un impacto fuerte se rompe en bloques con física.

const DEBRIS_LAYER := 1 << 2           # capa 3: escombros
const DEBRIS_MASK := 1 | 2 | 4 | 8     # mundo, eva, escombros, edificios
const CHUNK_TARGET_SIZE := 6.0
const MAX_CHUNKS_PER_AXIS := Vector3i(4, 8, 4)

@export var size := Vector3(20, 35, 20)
@export var color := Color(0.55, 0.57, 0.6)
@export var debris_lifetime := 8.0

var _destroyed := false
var _material: StandardMaterial3D


func _ready() -> void:
	collision_layer = 8   # capa 4: edificios
	collision_mask = 0
	_material = StandardMaterial3D.new()
	_material.albedo_color = color

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _material
	mesh.mesh = box
	mesh.position.y = size.y * 0.5
	add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position.y = size.y * 0.5
	add_child(shape)


## Devuelve true si el impacto lo derribó (false si ya estaba derribado).
func take_impact(impact_velocity: Vector3, _point: Vector3) -> bool:
	if _destroyed:
		return false
	_destroyed = true
	_collapse(impact_velocity)
	_spawn_dust()
	queue_free()
	return true


func _collapse(impact_velocity: Vector3) -> void:
	var counts := Vector3i(
		clampi(roundi(size.x / CHUNK_TARGET_SIZE), 1, MAX_CHUNKS_PER_AXIS.x),
		clampi(roundi(size.y / CHUNK_TARGET_SIZE), 1, MAX_CHUNKS_PER_AXIS.y),
		clampi(roundi(size.z / CHUNK_TARGET_SIZE), 1, MAX_CHUNKS_PER_AXIS.z))
	var chunk_size := size / Vector3(counts)
	var chunk_mesh := BoxMesh.new()
	chunk_mesh.size = chunk_size * 0.96
	chunk_mesh.material = _material
	var chunk_shape := BoxShape3D.new()
	chunk_shape.size = chunk_size * 0.96

	var parent := get_parent()
	var push := Vector3(impact_velocity.x, 0.0, impact_velocity.z)
	for x in counts.x:
		for y in counts.y:
			for z in counts.z:
				var body := RigidBody3D.new()
				body.collision_layer = DEBRIS_LAYER
				body.collision_mask = DEBRIS_MASK
				body.mass = chunk_size.x * chunk_size.y * chunk_size.z * 0.2
				var mi := MeshInstance3D.new()
				mi.mesh = chunk_mesh
				body.add_child(mi)
				var cs := CollisionShape3D.new()
				cs.shape = chunk_shape
				body.add_child(cs)
				var local := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * chunk_size - Vector3(size.x, 0, size.z) * 0.5
				parent.add_child(body)
				body.global_transform = global_transform * Transform3D(Basis.IDENTITY, local)
				# Los bloques altos salen más disparados: el edificio se vuelca hacia donde lo golpeaste.
				var height_factor := float(y + 1) / counts.y
				var spread := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 10.0
				body.linear_velocity = push * (0.5 + 0.7 * height_factor) + spread + Vector3.UP * randf_range(4.0, 14.0)
				body.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
				parent.get_tree().create_timer(debris_lifetime + randf() * 3.0).timeout.connect(body.queue_free)


func _spawn_dust() -> void:
	var dust := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(16, 16)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_circle()
	quad.material = mat
	dust.mesh = quad
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 48
	dust.lifetime = 3.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(size.x * 0.5, size.y * 0.3, size.z * 0.5)
	dust.direction = Vector3.UP
	dust.spread = 80.0
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 18.0
	dust.gravity = Vector3(0, -2.0, 0)
	dust.damping_min = 4.0
	dust.damping_max = 6.0
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.62, 0.6, 0.56, 0.55))
	ramp.set_color(1, Color(0.62, 0.6, 0.56, 0.0))
	dust.color_ramp = ramp
	get_parent().add_child(dust)
	dust.global_position = global_position + Vector3.UP * size.y * 0.3
	dust.emitting = true
	dust.finished.connect(dust.queue_free)


static var _dust_texture: GradientTexture2D

static func _soft_circle() -> GradientTexture2D:
	if _dust_texture:
		return _dust_texture
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_dust_texture = GradientTexture2D.new()
	_dust_texture.gradient = g
	_dust_texture.fill = GradientTexture2D.FILL_RADIAL
	_dust_texture.fill_from = Vector2(0.5, 0.5)
	_dust_texture.fill_to = Vector2(1.0, 0.5)
	_dust_texture.width = 64
	_dust_texture.height = 64
	return _dust_texture
