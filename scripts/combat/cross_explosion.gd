class_name CrossExplosion
extends Node3D
## La explosión en forma de cruz de los Ángeles. Sólo visual.

@export var height := 140.0
@export var duration := 1.4


static func spawn(context: Node, pos: Vector3, h: float) -> void:
	var cross := CrossExplosion.new()
	cross.height = h
	context.get_tree().root.add_child(cross)
	cross.global_position = pos


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.75, 0.35, 0.9)
	var width := height * 0.1
	# Pilar vertical y dos brazos cruzados para que se vea como cruz desde cualquier lado.
	_bar(Vector3(width, height, width), Vector3(0, height * 0.5, 0), mat)
	_bar(Vector3(height * 0.7, width, width), Vector3(0, height * 0.6, 0), mat)
	_bar(Vector3(width, width, height * 0.7), Vector3(0, height * 0.6, 0), mat)
	scale = Vector3(0.2, 0.2, 0.2)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration).set_delay(0.3)
	tween.chain().tween_callback(queue_free)


func _bar(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
