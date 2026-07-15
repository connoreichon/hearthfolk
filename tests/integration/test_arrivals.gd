extends HFTestCase
## Q3: llegadas de colonos con cama libre y excedente; nunca en invierno.

var _main: Node
var _tree_scene: SceneTree


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	GameState.setup_new_game(2222)
	GameState.add_resource(&"food", 80)
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	_tree_scene.root.add_child(_main)
	SimClock.reset(1, 0.3)
	SimClock.set_speed(0)


func after_each() -> void:
	_main.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()


func test_settler_gen_is_deterministic() -> void:
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 42
	var a: CitizenData = SettlerGen.generate(rng_a)
	var b: CitizenData = SettlerGen.generate(rng_b)
	assert_eq(a.display_name, b.display_name)
	assert_eq(a.shirt_color, b.shirt_color)
	assert_almost_eq(a.height_scale, b.height_scale)


func test_arrival_needs_bed_and_surplus() -> void:
	for _f: int in 10:
		await _tree_scene.process_frame
	assert_eq(_population(), 4)

	# Sin excedente: nadie llega aunque haya cama (4 camas base están llenas
	# → primero liberamos cama con una casa terminada)
	var nav_region: Node3D = _main.get_node("World/NavigationRegion3D") as Node3D
	var site: ConstructionSite = ConstructionSite.place(
		nav_region, Vector3(10.0, GameState.terrain.get_height(10.0, 10.0), 10.0), 0.0, 77
	)
	site.debug_complete()
	await _tree_scene.process_frame
	assert_eq(SettlerArrivals.total_beds(_tree_scene), 6, "4 base + 2 de la cabaña")

	GameState.inventory[&"food"] = 2
	SimClock.day_changed.emit(2)
	await _tree_scene.process_frame
	assert_eq(_population(), 4, "sin excedente nadie llega")

	# Con excedente y cama libre: llega un colono en primavera
	GameState.inventory[&"food"] = 60
	SimClock.day_changed.emit(2)
	await _tree_scene.process_frame
	assert_eq(_population(), 5, "llegó un colono")

	# En invierno no llega nadie
	SimClock.day = 7
	SimClock.day_changed.emit(7)
	await _tree_scene.process_frame
	assert_eq(_population(), 5, "en invierno no llega nadie")

	# Tope de camas: con 6 camas y 6 habitantes, no entra otro
	SimClock.day = 2
	SimClock.day_changed.emit(2)
	await _tree_scene.process_frame
	assert_eq(_population(), 6, "segunda llegada hasta llenar camas")
	SimClock.day_changed.emit(2)
	await _tree_scene.process_frame
	assert_eq(_population(), 6, "sin cama libre nadie más entra")


func test_spawn_point_is_always_connected_to_fire() -> void:
	# Regresión del soak 002: el borde sur puede formar islas de navmesh
	for _f: int in 15:
		await _tree_scene.process_frame
	var arrivals: SettlerArrivals = _main.get_node("World/SettlerArrivals")
	var world: Node3D = _main.get_node("World") as Node3D
	var fire_pos: Vector3 = (
		(_tree_scene.get_nodes_in_group(&"campfire")[0] as Node3D).global_position
	)
	var camp: CampEntity = CampEntity.nearest_camp(_tree_scene, Vector3.ZERO)
	for _try: int in 3:
		var spawn: Vector3 = arrivals._safe_spawn_point(world, camp)
		assert_true(
			NavUtil.is_reachable(world.get_world_3d(), fire_pos, spawn, 2.5),
			"el punto de aparición %s tiene ruta hasta la fogata" % str(spawn)
		)


func _population() -> int:
	return _tree_scene.get_nodes_in_group(&"citizens").size()
