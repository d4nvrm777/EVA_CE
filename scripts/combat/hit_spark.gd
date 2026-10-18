class_name HitSpark
extends CPUParticles3D
## Chispa de impacto de un solo uso. Color según el resultado del golpe.

const COLORS := {
	HitInfo.Result.HIT: Color(1.0, 0.25, 0.15),
	HitInfo.Result.AT_FIELD: Color(1.0, 0.6, 0.1),
	HitInfo.Result.BLOCKED: Color(1.0, 0.6, 0.1),
	HitInfo.Result.PARRIED: Color(1.0, 1.0, 0.9),
}

static var _mesh: QuadMesh


static func spawn(context: Node, point: Vector3, result: HitInfo.Result) -> void:
	var spark := HitSpark.new()
	spark.color = COLORS[result]
	spark.amount = 40 if result == HitInfo.Result.PARRIED else 24
	context.get_tree().root.add_child(spark)
	spark.global_position = point


func _ready() -> void:
	if not _mesh:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2(2.5, 2.5)
		var mat := StandardMaterial3D.new()
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		_mesh.material = mat
	mesh = _mesh
	one_shot = true
	explosiveness = 1.0
	lifetime = 0.35
	spread = 180.0
	initial_velocity_min = 40.0
	initial_velocity_max = 90.0
	gravity = Vector3.ZERO
	damping_min = 80.0
	damping_max = 120.0
	scale_amount_min = 0.5
	scale_amount_max = 1.5
	emitting = true
	finished.connect(queue_free)
