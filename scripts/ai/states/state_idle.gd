class_name StateIdle
extends CitizenState
## Espera breve entre acciones; después deambula.

var _wait: float = 0.0


func state_name() -> StringName:
	return &"Idle"


func enter() -> void:
	citizen.stop_moving()
	citizen.visual.mode = &"idle"
	_wait = citizen.local_rng.randf_range(2.0, 5.0)


func tick(dt: float) -> void:
	_wait -= dt
	if _wait <= 0.0:
		citizen.state_machine.change(&"Wander")
