class_name PowerSocket
extends StaticBody3D
## Enchufe para el cable umbilical. Torre placeholder con luz verde.

@export var height := 28.0

var _light_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("enchufes")
	collision_layer = 1   # mundo: el Eva choca, pero no lo derriba
	collision_mask = 0

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, height, 8)
	shape.shape = box
	shape.position.y = height * 0.5
	add_child(shape)

	var tower := MeshInstance3D.new()
	var tower_mesh := BoxMesh.new()
	tower_mesh.size = box.size
	var tower_mat := StandardMaterial3D.new()
	tower_mat.albedo_color = Color(0.18, 0.18, 0.2)
	tower_mesh.material = tower_mat
	tower.mesh = tower_mesh
	tower.position.y = height * 0.5
	add_child(tower)

	var light := MeshInstance3D.new()
	var light_mesh := BoxMesh.new()
	light_mesh.size = Vector3(9, 3, 9)
	_light_mat = StandardMaterial3D.new()
	_light_mat.albedo_color = Color(0.2, 1.0, 0.3)
	_light_mat.emission_enabled = true
	_light_mat.emission = Color(0.2, 1.0, 0.3)
	_light_mat.emission_energy_multiplier = 2.0
	light_mesh.material = _light_mat
	light.mesh = light_mesh
	light.position.y = height + 1.5
	add_child(light)


## Punto del que sale el cable.
func plug_point() -> Vector3:
	return global_position + Vector3.UP * height


func set_in_use(in_use: bool) -> void:
	var color := Color(1.0, 0.6, 0.1) if in_use else Color(0.2, 1.0, 0.3)
	_light_mat.albedo_color = color
	_light_mat.emission = color
