class_name BuildingPhase
extends Resource
## Fase de construcción: coste, trabajo y grupo de piezas visibles.

@export var display_name: String = "Cimientos"
@export var wood_cost: int = 3
@export var work_units: float = 20.0
@export var mesh_group: StringName = &"foundation"
