class_name UmbilicalCable
extends Node3D
## Dibuja el cable entre la espalda del Eva y el enchufe: segmentos de cilindro
## que cuelgan hasta el suelo y se tensan al llegar a la longitud máxima.

const SEGMENTS := 20

@export var power: EvaPower
@export var thickness := 2.5

var _segments: Array[MeshInstance3D] = []


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mesh := CylinderMesh.new()
	mesh.top_radius = thickness * 0.5
	mesh.bottom_radius = thickness * 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1)
	mesh.material = mat
	for i in SEGMENTS:
		var seg := MeshInstance3D.new()
		seg.mesh = mesh
		add_child(seg)
		_segments.append(seg)


func _process(_delta: float) -> void:
	var active := power.state == EvaPower.State.CONNECTED
	visible = active
	if not active:
		return
	var eva := power.body
	var back := eva.get_global_transform_interpolated()
	var start := back.origin + back.basis.z * 8.0 + Vector3.UP * 26.0
	var end := power.socket.plug_point()
	# Cuanta menos tensión, más cuelga (pero nunca bajo el suelo).
	var slack := 1.0 - power.tension()
	var sag := start.distance_to(end) * 0.5 * slack
	var prev := start
	for i in SEGMENTS:
		var t := float(i + 1) / SEGMENTS
		var p := start.lerp(end, t)
		p.y = maxf(p.y - sag * 4.0 * t * (1.0 - t), 0.8)
		_place(_segments[i], prev, p)
		prev = p


func _place(seg: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		seg.visible = false
		return
	seg.visible = true
	var y := (b - a) / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	seg.global_transform = Transform3D(Basis(x, y * length, z), (a + b) * 0.5)
