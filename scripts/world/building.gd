class_name Building
extends StaticBody3D
## Edificio placeholder. Al recibir un impacto fuerte se rompe en bloques con física.

const DEBRIS_LAYER := 1 << 2           # capa 3: escombros
const DEBRIS_MASK := 1 | 2 | 4 | 8     # mundo, eva, escombros, edificios
const MAX_CHUNKS_PER_AXIS := Vector3i(3, 6, 3)

@export var size := Vector3(30, 80, 30)
@export var color := Color(0.55, 0.57, 0.6)
@export var debris_lifetime := 12.0

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


func take_impact(impact_velocity: Vector3, _point: Vector3) -> void:
	if _destroyed:
		return
	_destroyed = true
	_collapse(impact_velocity)
	queue_free()


func _collapse(impact_velocity: Vector3) -> void:
	var counts := Vector3i(
		clampi(roundi(size.x / 12.0), 1, MAX_CHUNKS_PER_AXIS.x),
		clampi(roundi(size.y / 15.0), 1, MAX_CHUNKS_PER_AXIS.y),
		clampi(roundi(size.z / 12.0), 1, MAX_CHUNKS_PER_AXIS.z))
	var chunk_size := size / Vector3(counts)
	var chunk_mesh := BoxMesh.new()
	chunk_mesh.size = chunk_size * 0.98
	chunk_mesh.material = _material
	var chunk_shape := BoxShape3D.new()
	chunk_shape.size = chunk_size * 0.98

	var parent := get_parent()
	var push := impact_velocity * Vector3(1, 0, 1) * 0.5
	for x in counts.x:
		for y in counts.y:
			for z in counts.z:
				var body := RigidBody3D.new()
				body.collision_layer = DEBRIS_LAYER
				body.collision_mask = DEBRIS_MASK
				body.mass = chunk_size.x * chunk_size.y * chunk_size.z * 0.5
				var mi := MeshInstance3D.new()
				mi.mesh = chunk_mesh
				body.add_child(mi)
				var cs := CollisionShape3D.new()
				cs.shape = chunk_shape
				body.add_child(cs)
				var local := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * chunk_size - Vector3(size.x, 0, size.z) * 0.5
				parent.add_child(body)
				body.global_transform = global_transform * Transform3D(Basis.IDENTITY, local)
				# Los bloques altos salen más empujados: el edificio se vuelca hacia donde lo golpeaste.
				var height_factor := float(y + 1) / counts.y
				body.linear_velocity = push * height_factor + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
				body.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
				parent.get_tree().create_timer(debris_lifetime + randf() * 3.0).timeout.connect(body.queue_free)
