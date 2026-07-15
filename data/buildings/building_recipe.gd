class_name BuildingRecipe
extends Resource
## Receta de edificio (§3): dimensiones y fases de construcción.

@export var id: StringName = &"cottage_a"
@export var display_name: String = "Cabaña"
@export var footprint: Vector2 = Vector2(5.0, 4.0)
@export var wall_height: float = 2.6
@export var total_height: float = 4.2
@export var sleep_slots: int = 2
@export var phases: Array[BuildingPhase] = []
## S7 — Nivel de la casa (1 choza · 2 cabaña · 3 casa de piedra) y su mejora
## al nivel siguiente (ruta de receta + coste en madera de la mejora).
@export var tier: int = 2
@export var upgrade_to: String = ""
@export var upgrade_cost: int = 0


func total_wood_cost() -> int:
	var total: int = 0
	for phase: BuildingPhase in phases:
		total += phase.wood_cost
	return total


## Coste acumulado hasta la fase index (1-based) incluida.
func cumulative_cost(upto_phase: int) -> int:
	var total: int = 0
	for i: int in mini(upto_phase, phases.size()):
		total += phases[i].wood_cost
	return total
