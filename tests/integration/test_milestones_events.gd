extends HFTestCase
## Q5: hitos que se cumplen y eventos suaves que hacen lo que dicen.

var _main: Node
var _tree_scene: SceneTree


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	GameState.setup_new_game(2222)
	GameState.add_resource(&"food", 12)
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


func test_milestones_complete_and_reward_bond() -> void:
	for _f: int in 10:
		await _tree_scene.process_frame
	var milestones: Milestones = _main.get_node("World/Milestones")
	var citizen: Citizen = _tree_scene.get_nodes_in_group(&"citizens")[0] as Citizen
	citizen.bond = 50.0
	assert_false(milestones.is_done("first_tree"))
	EventBus.tree_felled.emit(999, Vector3.ZERO, 6)
	assert_true(milestones.is_done("first_tree"), "hito de primer árbol")
	assert_almost_eq(citizen.bond, 60.0, 0.01, "recompensa de vínculo +10")

	var nav_region: Node3D = _main.get_node("World/NavigationRegion3D") as Node3D
	var site: ConstructionSite = ConstructionSite.place(
		nav_region, Vector3(10.0, GameState.terrain.get_height(10.0, 10.0), 10.0), 0.0, 77
	)
	site.debug_complete()
	assert_true(milestones.is_done("first_house"), "hito de primera casa")

	GameState.inventory[&"food"] = 70
	SimClock.day_changed.emit(2)
	assert_true(milestones.is_done("full_granary"), "hito de granero lleno")

	# Persistencia del estado de hitos
	var saved: Array = milestones.save_state()
	milestones.load_state([])
	assert_false(milestones.is_done("first_tree"))
	milestones.load_state(saved)
	assert_true(milestones.is_done("first_tree"), "hitos restaurados del guardado")
	assert_true("☑" in milestones.summary(), "el resumen marca casillas")


func test_frost_and_traveler_events() -> void:
	for _f: int in 10:
		await _tree_scene.process_frame
	var events: WorldEvents = _main.get_node("World/WorldEvents")
	var nav_region: Node3D = _main.get_node("World/NavigationRegion3D") as Node3D
	var farm: FarmField = FarmField.place(nav_region, Rect2(6.0, 6.0, 4.0, 4.0))
	await _tree_scene.process_frame
	farm.plots[0] = FarmField.Plot.SPROUT
	farm.plots[1] = FarmField.Plot.SPROUT
	farm.plots[2] = FarmField.Plot.MATURE
	events.apply_frost()
	assert_eq(int(farm.plots[0]), int(FarmField.Plot.PLANTED), "helada: brote retrocede")
	assert_eq(int(farm.plots[1]), int(FarmField.Plot.PLANTED))
	assert_eq(int(farm.plots[2]), int(FarmField.Plot.MATURE), "lo maduro aguanta la helada")

	var food_before: int = GameState.get_resource(&"food")
	events.apply_traveler()
	assert_eq(GameState.get_resource(&"food"), food_before + 6, "el viajero deja 6 de comida")
