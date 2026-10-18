class_name HitInfo
extends RefCounted
## Un golpe que alguien recibe. receive_hit() devuelve un Result.

enum Result { HIT, BLOCKED, PARRIED, AT_FIELD }

var attacker: Node3D
var damage := 0.0
var at_damage := 0.0
var knockback := Vector3.ZERO
var point := Vector3.ZERO
var hitstop := 0.0
var stagger := 0.0
var unblockable := false     ## agarres: el AT Field no lo para


## true si el golpe viene de delante de `defender` (dentro de ±`half_angle_deg`).
func is_frontal(defender: Node3D, half_angle_deg := 75.0) -> bool:
	var to_attacker := attacker.global_position - defender.global_position
	to_attacker.y = 0.0
	if to_attacker.length_squared() < 0.01:
		return true
	return (-defender.global_basis.z).angle_to(to_attacker.normalized()) <= deg_to_rad(half_angle_deg)
