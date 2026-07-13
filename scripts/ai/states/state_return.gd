class_name StateReturnToSettlement
extends CitizenState
## Volver al asentamiento (de noche) y pasar a descansar.


func state_name() -> StringName:
	return &"ReturnToSettlement"


func enter() -> void:
	citizen.visual.mode = &"walk"
	citizen.move_to(citizen.rest_spot())


func tick(_dt: float) -> void:
	if citizen.nav_finished():
		if SimClock.is_night():
			citizen.state_machine.change(&"Rest")
		else:
			citizen.state_machine.change(&"Idle")
