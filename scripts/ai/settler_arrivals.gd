class_name SettlerArrivals
extends Node
## Q3: si hay cama libre y excedente de comida, en primavera/verano llega
## un caminante por el camino del sur al amanecer.

const BASE_BEDS: int = 4
const MAX_POPULATION: int = 12
const FOOD_PER_CAPITA: int = 4
const CITIZEN_SCENE: PackedScene = preload("res://scenes/citizens/citizen.tscn")


static func total_beds(tree: SceneTree) -> int:
	var beds: int = BASE_BEDS
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
	var data: CitizenData = SettlerGen.generate(GameState.rng)
	var citizen: Citizen = CITIZEN_SCENE.instantiate()
	citizen.data = data
	(worlds[0] as Node3D).add_child(citizen)
	citizen.global_position = _safe_spawn_point(worlds[0] as Node3D)
	citizen.state_machine.change(&"ReturnToSettlement")
	EventBus.toast.emit(
		"¡%s ha llegado al asentamiento buscando un hogar!" % data.display_name, &"success"
	)
	AudioDirector.play_ui(&"ui_confirm")


## Punto de entrada por el camino del sur, garantizando que hay ruta hasta
## la fogata (el borde del navmesh puede formar islas sueltas — visto en el
## soak 002: colono atascado >15 s al aparecer).
func _safe_spawn_point(world: Node3D) -> Vector3:
	var fire_pos: Vector3 = Vector3.ZERO
	var fires: Array[Node] = get_tree().get_nodes_in_group(&"campfire")
	if not fires.is_empty():
		fire_pos = (fires[0] as Node3D).global_position
	var world_3d: World3D = world.get_world_3d()
	var map: RID = world_3d.navigation_map
	for z: float in [56.0, 50.0, 44.0, 36.0, 26.0]:
		var x: float = sin(z * 0.045) * 3.0
		var candidate: Vector3 = Vector3(x, GameState.terrain.get_height(x, z), z)
		var snapped_point: Vector3 = NavigationServer3D.map_get_closest_point(map, candidate)
		if NavUtil.is_reachable(world_3d, fire_pos, snapped_point, 2.0):
			snapped_point.y += 0.05
			return snapped_point
	# Último recurso: junto a la fogata (nunca aislado)
	return fire_pos + Vector3(2.0, 0.1, 2.0)
