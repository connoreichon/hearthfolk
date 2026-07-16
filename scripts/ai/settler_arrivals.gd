class_name SettlerArrivals
extends Node
## Q3: si hay cama libre y excedente de comida, en primavera/verano llega
## un caminante por el camino del sur al amanecer.

## Petates junto a la hoguera de cada campamento fundado (4 = el clásico
## de la 002 con un solo campamento; se rebalanceará en S9).
const BEDS_PER_CAMP: int = 4
const MAX_POPULATION: int = 12
const FOOD_PER_CAPITA: int = 4
const CITIZEN_SCENE: PackedScene = preload("res://scenes/citizens/citizen.tscn")


static func total_beds(tree: SceneTree) -> int:
	# Base por campamento fundado (petates junto a la hoguera), no fija.
	var beds: int = BEDS_PER_CAMP * tree.get_nodes_in_group(&"camps").size()
	for node: Node in tree.get_nodes_in_group(&"buildings"):
		var building: ConstructionSite = node as ConstructionSite
		if building != null and building.completed:
			beds += building.recipe.sleep_slots
	return beds


func _ready() -> void:
	SimClock.day_changed.connect(_on_day_changed)


func _on_day_changed(_day: int) -> void:
	if SimClock.get_season() > SimClock.Season.SUMMER:
		return
	var population: int = get_tree().get_nodes_in_group(&"citizens").size()
	if population >= mini(total_beds(get_tree()), MAX_POPULATION):
		return
	if GameState.get_resource(&"food") < population * FOOD_PER_CAPITA:
		return
	_spawn_settler()


func _spawn_settler() -> void:
	var worlds: Array[Node] = get_tree().get_nodes_in_group(&"world")
	if worlds.is_empty() or GameState.terrain == null:
		return
	# El recién llegado se une a la aldea con MÁS SITIO (no siempre a la más
	# cercana al origen del mundo, que la hacía engordar sola y atascaba su
	# hoguera con multitud). Reparto entre bandas → aldeas parejas.
	var home: CampEntity = _roomiest_camp()
	if home == null:
		return
	var data: CitizenData = SettlerGen.generate(GameState.rng)
	# El caminante llega con sus propias herramientas (viene de mundo)
	data.has_tools = true
	var citizen: Citizen = CITIZEN_SCENE.instantiate()
	citizen.data = data
	(worlds[0] as Node3D).add_child(citizen)
	citizen.band_id = home.band_id
	citizen.global_position = _safe_spawn_point(worlds[0] as Node3D, home)
	citizen.state_machine.change(&"ReturnToSettlement")
	EventBus.toast.emit(
		"¡%s se une a %s buscando un hogar!" % [data.display_name, home.settlement_name], &"success"
	)
	AudioDirector.play_ui(&"ui_confirm")


## La aldea con más plazas libres (camas de la banda − población de la banda);
## empates a favor de la menos poblada. Reparte el crecimiento entre bandas.
func _roomiest_camp() -> CampEntity:
	var best: CampEntity = null
	var best_room: int = -999
	for node: Node in get_tree().get_nodes_in_group(&"camps"):
		var camp: CampEntity = node as CampEntity
		if camp == null:
			continue
		var room: int = _beds_of_band(camp.band_id) - _population_of_band(camp.band_id)
		if room > best_room:
			best_room = room
			best = camp
	return best


func _population_of_band(band: int) -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"citizens"):
		if (node as Citizen).band_id == band:
			count += 1
	return count


func _beds_of_band(band: int) -> int:
	var beds: int = BEDS_PER_CAMP
	for node: Node in get_tree().get_nodes_in_group(&"buildings"):
		var building: ConstructionSite = node as ConstructionSite
		if building == null or not building.completed:
			continue
		var camp: CampEntity = CampEntity.camp_of_band(get_tree(), band)
		if (
			camp != null
			and (
				building.global_position.distance_to(camp.global_position)
				<= CampEntity.TERRITORY_RADIUS
			)
		):
			beds += building.recipe.sleep_slots
	return beds


## Mapa gigante (S1): el recién llegado aparece «desde el horizonte» en un
## anillo alrededor de SU campamento, con ruta real validada hasta su
## hoguera (el borde del navmesh puede formar islas — soak 002).
func _safe_spawn_point(world: Node3D, camp: CampEntity) -> Vector3:
	if camp == null:
		return Vector3.ZERO
	var fire_pos: Vector3 = camp.global_position
	var world_3d: World3D = world.get_world_3d()
	var map: RID = world_3d.navigation_map
	# Mapa sin sincronizar (primeros frames): junto a la fogata y listo
	if not NavUtil.map_ready(map):
		return fire_pos + Vector3(2.0, 0.1, 2.0)
	for radius: float in [26.0, 20.0, 14.0]:
		for step: int in 8:
			var ang: float = TAU * float(step) / 8.0 + radius
			var x: float = fire_pos.x + cos(ang) * radius
			var z: float = fire_pos.z + sin(ang) * radius
			var candidate: Vector3 = Vector3(x, GameState.terrain.get_height(x, z), z)
			var snapped_point: Vector3 = NavigationServer3D.map_get_closest_point(map, candidate)
			if NavUtil.is_reachable(world_3d, fire_pos, snapped_point, 2.0):
				snapped_point.y += 0.05
				return snapped_point
	# Último recurso: junto a la fogata (nunca aislado)
	return fire_pos + Vector3(2.0, 0.1, 2.0)
