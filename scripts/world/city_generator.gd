extends Node3D
## Genera una cuadrícula de edificios placeholder alrededor de una plaza central.

@export var city_seed := 1995
@export var blocks := 20                ## manzanas por lado
@export var block_spacing := 55.0
@export var plaza_radius := 2           ## manzanas libres alrededor del centro
@export var min_height := 12.0
@export var max_height := 45.0
@export var tower_chance := 0.08       ## algunos rascacielos sueltos
@export var tower_height := Vector2(60.0, 90.0)


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
			var tall := rng.randf() < tower_chance
			var height := rng.randf_range(tower_height.x, tower_height.y) if tall else rng.randf_range(min_height, max_height)
			building.size = Vector3(rng.randf_range(14.0, 28.0), height, rng.randf_range(14.0, 28.0))
			var shade := rng.randf_range(0.4, 0.7)
			building.color = Color(shade, shade, shade * 1.05)
			building.position = Vector3((gx + 0.5) * block_spacing, 0.0, (gz + 0.5) * block_spacing)
			add_child(building)
