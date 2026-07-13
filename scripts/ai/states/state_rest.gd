class_name StateRest
extends CitizenState
## Dormir junto a la fogata (en P6, hasta 2 dentro de la casa terminada).
## La energía sube según sim_config; despiertan al amanecer.

var _sleeping: bool = false


func state_name() -> StringName:
	return &"Rest"


func enter() -> void:
	_sleeping = false
	var spot: Vector3 = citizen.rest_spot()
	citizen.visual.mode = &"walk"
	citizen.move_to(spot)


func tick(dt: float) -> void:
	if not _sleeping:
		if not citizen.nav_finished():
			return
		citizen.stop_moving()
		_sleeping = true
		citizen.visual.mode = &"rest"
		return
	var cfg: SimConfig = SimConfig.get_default()
	citizen.energy = minf(
		100.0, citizen.energy + cfg.energy_recovered_per_sim_minute_resting * dt / 60.0
	)
	var is_daytime: bool = SimClock.get_phase() <= SimClock.Phase.DAY
	if citizen.energy >= 99.9 and is_daytime:
		citizen.state_machine.change(&"Idle")
	elif is_daytime and SimClock.get_phase() == SimClock.Phase.DAWN and citizen.energy > 60.0:
		citizen.state_machine.change(&"Idle")


func exit() -> void:
	citizen.visual.mode = &"idle"
