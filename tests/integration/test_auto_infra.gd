extends HFTestCase
## S2: infraestructura autoconstruida — la aldea rotura su huerto cuando
## la comida aprieta y levanta su cobertizo cuando crece; los oficios se
## reparten solos según la necesidad real del mundo.

const CITIZEN_SCENE: PackedScene = preload("res://scenes/citizens/citizen.tscn")

var _tree_scene: SceneTree
var _main: Node


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	GameState.setup_new_game(2222)
	# Madera holgada (la auto-tala no roba obreros) y comida BAJO el umbral
	# del huerto (target 26 × 0.6 ≈ 15.6 con 4 habitantes)
	GameState.add_resource(&"wood", 24)
	GameState.add_resource(&"food", 2)
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	_tree_scene.root.add_child(_main)
	SimClock.reset(1, 0.2)
	SimClock.set_speed(4)
	for _f: int in 20:
		await _tree_scene.process_frame


func after_each() -> void:
	_main.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()


func test_hungry_village_plows_its_own_farm() -> void:
	var camp: CampEntity = _tree_scene.get_nodes_in_group(&"camps")[0] as CampEntity
	var farm: FarmField = null
	for _f: int in 5200:
		await _tree_scene.process_frame
		var farms: Array[Node] = _tree_scene.get_nodes_in_group(&"farms")
		if not farms.is_empty():
			farm = farms[0] as FarmField
			break
	assert_true(farm != null, "con la comida bajo el 60 %% del objetivo nace un huerto solo")
	if farm != null:
		assert_true(
			farm.global_position.distance_to(camp.global_position) <= CampEntity.TERRITORY_RADIUS,
			"el huerto se rotura DENTRO del territorio"
		)
		assert_true(farm.plot_count() > 0, "con parcelas de verdad")


func test_professions_follow_demand() -> void:
	# Espera a que el barrido inicial asigne oficio a los 4 fundadores
	var citizens: Array[Node] = _tree_scene.get_nodes_in_group(&"citizens")
	assert_eq(citizens.size(), 4)
	for _f: int in 600:
		await _tree_scene.process_frame
		var all_assigned: bool = true
		for node: Node in citizens:
			if (node as Citizen).data.profession == &"":
				all_assigned = false
				break
		if all_assigned:
			break
	var lumberjacks: int = 0
	for node: Node in citizens:
		var citizen: Citizen = node as Citizen
		assert_ne(citizen.data.profession, &"", "%s tiene oficio" % citizen.data.display_name)
		if citizen.data.profession == &"lenador":
			lumberjacks += 1
	# La partida arranca con 24 de madera (target 24): la leña NO aprieta,
	# así que no puede haber una aldea entera de leñadores
	assert_true(lumberjacks < 4, "sin crisis de leña no hay monocultivo de leñadores")
	# Crisis de leña + reevaluación estacional → aparecen leñadores
	GameState.take_resource(&"wood", GameState.get_resource(&"wood"))
	var planner: ProfessionPlanner = (
		_tree_scene.get_first_node_in_group(&"profession_planner") as ProfessionPlanner
	)
	planner.evaluate_all()
	lumberjacks = 0
	for node: Node in citizens:
		if (node as Citizen).data.profession == &"lenador":
			lumberjacks += 1
	assert_true(lumberjacks >= 2, "leña a cero: VARIOS leñadores a la vez (la demanda manda)")


func test_grown_village_raises_supply_shed() -> void:
	var camp: CampEntity = _tree_scene.get_nodes_in_group(&"camps")[0] as CampEntity
	# Comida holgada para que el hambre no interfiera y población a 6
	GameState.add_resource(&"food", 40)
	for i: int in 2:
		var citizen: Citizen = CITIZEN_SCENE.instantiate()
		citizen.data = SettlerGen.generate(GameState.rng)
		citizen.band_id = camp.band_id
		_main.get_node("World/NavigationRegion3D").add_child(citizen)
		citizen.global_position = (
			camp.global_position + Vector3(2.0 + float(i), 0.2, -2.0 - float(i))
		)
	assert_eq(camp.population(), 6)
	var shed: ConstructionSite = null
	for _f: int in 2400:
		await _tree_scene.process_frame
		for node: Node in _tree_scene.get_nodes_in_group(&"construction_sites"):
			var site: ConstructionSite = node as ConstructionSite
			if site != null and site.recipe.id == &"shed":
				shed = site
				break
		if shed != null:
			break
	assert_true(shed != null, "a 6 habitantes la aldea planta la obra de su cobertizo")
	if shed != null:
		shed.debug_complete()
		assert_true(shed.completed, "el cobertizo se puede terminar")
		assert_true(shed.is_in_group(&"storage"), "y al terminar ES un punto de almacenaje")
		assert_true(
			CampEntity.nearest_storage_node(_tree_scene, shed.global_position) == shed,
			"los porteadores lo encuentran como almacén más cercano"
		)
