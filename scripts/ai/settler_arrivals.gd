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
	# Entra por el camino del sur
	var x: float = sin(56.0 * 0.045) * 3.0
	var pos: Vector3 = Vector3(x, 0.0, 56.0)
	pos.y = GameState.terrain.get_height(pos.x, pos.z) + 0.05
	citizen.global_position = pos
	citizen.state_machine.change(&"ReturnToSettlement")
	EventBus.toast.emit(
		"¡%s ha llegado al asentamiento buscando un hogar!" % data.display_name, &"success"
	)
	AudioDirector.play_ui(&"ui_confirm")
