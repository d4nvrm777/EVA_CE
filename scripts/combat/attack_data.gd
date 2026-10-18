class_name AttackData
extends Resource
## Definición de un ataque. Los tiempos van en segundos.

@export var display_name := "ataque"
@export var damage := 6.0
@export var at_damage := 10.0           ## daño al AT Field del objetivo
@export var startup := 0.1              ## antes de que golpee
@export var active := 0.08              ## ventana en la que golpea
@export var recovery := 0.22            ## después; se puede encadenar desde aquí
@export var reach := 18.0               ## distancia del centro del golpe delante del Eva
@export var radius := 14.0
@export var height := 22.0
@export var lunge_speed := 25.0         ## avance durante startup + active
@export var hitstop := 0.06
@export var knockback := 8.0
@export var stagger := 0.3              ## aturdimiento que causa al golpear


func total_time() -> float:
	return startup + active + recovery
