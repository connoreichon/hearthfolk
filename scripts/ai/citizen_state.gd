class_name CitizenState
extends RefCounted
## Estado base de la FSM de habitantes. Cada estado vive en su archivo.

var citizen: Citizen


func state_name() -> StringName:
	return &""


func enter() -> void:
	pass


func tick(_dt: float) -> void:
	pass


func exit() -> void:
	pass


## Notificación de bloqueo detectado; por defecto se reintenta el estado.
func on_stuck() -> void:
	enter()
