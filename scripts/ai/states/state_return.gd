class_name StateReturnToSettlement
extends CitizenState
## Volver al asentamiento (de noche) y pasar a descansar.

var _spot: Vector3 = Vector3.ZERO


func state_name() -> StringName:
	return &"ReturnToSettlement"


func enter() -> void:
	citizen.visual.mode = &"walk"
	_spot = citizen.rest_spot()
	citizen.move_to(_spot)


func tick(_dt: float) -> void:
	var close: bool = citizen.global_position.distance_to(_spot) < 1.3
	if citizen.nav_finished() or close:
		if SimClock.is_night():
			citizen.state_machine.change(&"Rest")
		else:
			citizen.state_machine.change(&"Idle")
