class_name ProfessionPlanner
extends Node
## S2 — La demanda manda: cada colono elige oficio por utilidad
## (necesidad de SU aldea × aptitud propia), con histéresis anti-flapping.
## Reevaluación SOLO al cambiar la estación (+ recién llegados sin oficio
## en una pasada lenta): el flapping muere por diseño (docs/S2_DESIGN.md §5).

const NEWCOMER_SWEEP_SECONDS: float = 5.0

var _sweep_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"profession_planner")
	SimClock.season_changed.connect(_on_season_changed)
	SimClock.sim_tick.connect(_on_sim_tick)
	# Reparto inmediato al sembrar una banda: nada de fundadores sin oficio
	# esperando al barrido (el jugador está mirando justo en ese momento).
	EventBus.band_placed.connect(_on_band_placed)


func _on_band_placed(_band_id: int, _center: Vector3) -> void:
	if is_inside_tree():
		evaluate_all.call_deferred()


func _on_season_changed(_season: int) -> void:
	if not is_inside_tree():
		return
	evaluate_all()


func _on_sim_tick(dt: float) -> void:
	if not is_inside_tree():
		return
	_sweep_timer -= dt
	if _sweep_timer > 0.0:
		return
	_sweep_timer = NEWCOMER_SWEEP_SECONDS
	# Solo los sin oficio (recién sembrados, llegadas, cargas antiguas)
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		var citizen: Citizen = node as Citizen
		if citizen != null and citizen.data.profession == &"":
			_evaluate(citizen, _needs_for_band(citizen.band_id))


## Reevaluación completa (cambio de estación o llamada de test).
func evaluate_all() -> void:
	var needs_by_band: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		var citizen: Citizen = node as Citizen
		if citizen == null:
			continue
		if not needs_by_band.has(citizen.band_id):
			needs_by_band[citizen.band_id] = _needs_for_band(citizen.band_id)
		_evaluate(citizen, needs_by_band[citizen.band_id])


func _evaluate(citizen: Citizen, needs: Dictionary) -> void:
	var chosen: StringName = Professions.choose(citizen.data, needs)
	if chosen == citizen.data.profession:
		return
	citizen.data.profession = chosen
	EventBus.profession_changed.emit(citizen.entity_id, chosen)


## Necesidades 0..1 de la aldea de una banda (docs/S2_DESIGN.md §4).
func _needs_for_band(band: int) -> Dictionary:
	var camp: CampEntity = CampEntity.camp_of_band(get_tree(), band)
	if camp == null:
		return {&"recolector": 0.35}
	var wood: float = float(GameState.get_resource(&"wood"))
	var food: float = float(GameState.get_resource(&"food"))
	var food_target: float = float(10 + 4 * camp.population())
	var needs: Dictionary = {
		&"lenador": clampf(1.0 - wood / float(CampEntity.WOOD_TARGET), 0.0, 1.0) * 0.9 + 0.1,
		&"recolector": 0.35,
	}
	# Agricultor: sin huerto en el territorio no hay tierra que trabajar
	if _band_has_nearby(camp, &"farms"):
		needs[&"agricultor"] = clampf(1.0 - food / food_target, 0.0, 1.0) * 0.9 + 0.1
	else:
		needs[&"agricultor"] = 0.05
	# Constructor: obra pendiente de la aldea = urgencia máxima
	needs[&"constructor"] = 1.0 if _band_has_pending_site(camp) else 0.05
	return needs


func _band_has_nearby(camp: CampEntity, group: StringName) -> bool:
	for node: Node in get_tree().get_nodes_in_group(group):
		var spot: Node3D = node as Node3D
		if spot == null:
			continue
		if (
			spot.global_position.distance_to(camp.global_position)
			<= CampEntity.TERRITORY_RADIUS * 1.5
		):
			return true
	return false


func _band_has_pending_site(camp: CampEntity) -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"construction_sites"):
		var site: ConstructionSite = node as ConstructionSite
		if site == null or site.completed or site.demolished:
			continue
		if (
			site.global_position.distance_to(camp.global_position)
			<= CampEntity.TERRITORY_RADIUS * 1.5
		):
			return true
	return false
