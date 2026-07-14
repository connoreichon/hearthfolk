class_name StateRest
extends CitizenState
## Dormir junto a la fogata (en P6, hasta 2 dentro de la casa terminada).
## La energía sube según sim_config; despiertan al amanecer.

var _sleeping: bool = false
var _cottage: ConstructionSite
var _spot: Vector3 = Vector3.ZERO


func state_name() -> StringName:
	return &"Rest"


func enter() -> void:
	_sleeping = false
	_cottage = _claim_cottage()
	citizen.visual.mode = &"walk"
	if _cottage != null:
		_spot = _cottage.door_position()
	else:
		_spot = citizen.rest_spot()
	citizen.move_to(_spot)


func tick(dt: float) -> void:
	if not _sleeping:
		var close: bool = citizen.global_position.distance_to(_spot) < 1.3
		if not citizen.nav_finished() and not close:
			return
		citizen.stop_moving()
		_sleeping = true
		if _cottage != null and is_instance_valid(_cottage):
			# Duerme dentro: se oculta y la ventana se enciende de noche
			citizen.visible = false
			citizen.sleeping_indoors = true
		else:
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
	citizen.visible = true
	citizen.sleeping_indoors = false
	citizen.visual.mode = &"idle"
	if _cottage != null and is_instance_valid(_cottage):
		_cottage.release_sleep_slot(citizen.entity_id)
	_cottage = null


## Hasta 2 habitantes duermen en una cabaña terminada (§7.5).
func _claim_cottage() -> ConstructionSite:
	for node: Node in citizen.get_tree().get_nodes_in_group(&"buildings"):
		var building: ConstructionSite = node as ConstructionSite
		if building != null and building.claim_sleep_slot(citizen.entity_id):
			return building
	return null
