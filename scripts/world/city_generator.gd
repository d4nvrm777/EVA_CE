extends Node3D
## Genera una cuadrícula de edificios placeholder alrededor de una plaza central.

@export var city_seed := 1995
@export var blocks := 12                ## manzanas por lado
@export var block_spacing := 90.0
@export var plaza_radius := 2           ## manzanas libres alrededor del centro
@export var min_height := 30.0
@export var max_height := 140.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = city_seed
	var half := blocks >> 1
	for gx in range(-half, half):
		for gz in range(-half, half):
			if absi(gx) < plaza_radius and absi(gz) < plaza_radius:
				continue
			if rng.randf() < 0.15:
				continue  # huecos para que no sea un tablero perfecto
			var building := Building.new()
			var footprint := rng.randf_range(25.0, 50.0)
			building.size = Vector3(footprint, rng.randf_range(min_height, max_height), rng.randf_range(25.0, 50.0))
			var shade := rng.randf_range(0.4, 0.7)
			building.color = Color(shade, shade, shade * 1.05)
			building.position = Vector3((gx + 0.5) * block_spacing, 0.0, (gz + 0.5) * block_spacing)
			add_child(building)
