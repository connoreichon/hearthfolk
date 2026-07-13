class_name StateWander
extends CitizenState
## Paseo aleatorio cerca del asentamiento.

const RADIUS_MIN: float = 3.0
const RADIUS_MAX: float = 13.0

var _timeout: float = 0.0


func state_name() -> StringName:
	return &"Wander"


func enter() -> void:
	citizen.visual.mode = &"walk"
	_timeout = 25.0
	var ang: float = citizen.local_rng.randf() * TAU
	var radius: float = citizen.local_rng.randf_range(RADIUS_MIN, RADIUS_MAX)
	var target: Vector3 = Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
	if GameState.terrain != null:
		target.y = GameState.terrain.get_height(target.x, target.z)
	citizen.move_to(target)


func tick(dt: float) -> void:
	_timeout -= dt
	if citizen.nav_finished() or _timeout <= 0.0:
		citizen.state_machine.change(&"Idle")
