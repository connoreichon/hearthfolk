extends Node3D
## Punto de entrada. Registra el mapa de entrada; el mundo se monta en P1.


func _ready() -> void:
	InputSetup.setup()
