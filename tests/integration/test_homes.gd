extends HFTestCase
## S7: las casas se autoconstruyen y MEJORAN por niveles (choza → cabaña →
## casa de piedra), subiendo camas y consumiendo madera.

var _tree_scene: SceneTree
var _main: Node


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	GameState.setup_new_game(2024)
	GameState.add_resource(&"wood", 60)
	GameState.add_resource(&"food", 30)
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	_tree_scene.root.add_child(_main)
	SimClock.reset(1, 0.2)
	# Pausa: aislar la mejora manual del planificador del campamento.
	SimClock.set_speed(0)
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


func _place_choza() -> ConstructionSite:
	var fire: Vector3 = (_tree_scene.get_nodes_in_group(&"campfire")[0] as Node3D).global_position
	var at: Vector3 = fire + Vector3(12.0, 0.0, 12.0)
	at.y = GameState.terrain.get_height(at.x, at.z)
	var nav: Node3D = _main.get_node("World/NavigationRegion3D") as Node3D
	return ConstructionSite.place(nav, at, 0.0, 555, 0, "res://data/buildings/choza.tres")


func test_house_upgrades_through_tiers() -> void:
	var site: ConstructionSite = _place_choza()
	await _tree_scene.process_frame
	assert_eq(site.recipe.id, &"choza", "nace como choza")
	assert_eq(site.recipe.tier, 1)
	assert_eq(site.recipe.sleep_slots, 1, "la choza da 1 cama")
	site.debug_complete()
	assert_true(site.completed, "la choza se termina")

	var wood_before: int = GameState.get_resource(&"wood")
	assert_true(site.upgrade_to_next(), "la choza sube a cabaña")
	assert_eq(site.recipe.id, &"cottage_a", "ahora es cabaña")
	assert_eq(site.recipe.tier, 2)
	assert_eq(site.recipe.sleep_slots, 2, "la cabaña da 2 camas")
	assert_eq(GameState.get_resource(&"wood"), wood_before - 8, "la mejora costó 8 de madera")
	assert_true(site.completed, "sigue habitable tras mejorar")

	assert_true(site.upgrade_to_next(), "la cabaña sube a casa de piedra")
	assert_eq(site.recipe.id, &"casa_piedra")
	assert_eq(site.recipe.tier, 3)
	assert_eq(site.recipe.sleep_slots, 3, "la casa de piedra da 3 camas")
	assert_false(site.upgrade_to_next(), "la casa de piedra es el tope")


func test_upgrade_needs_wood() -> void:
	var site: ConstructionSite = _place_choza()
	await _tree_scene.process_frame
	site.debug_complete()
	# Vaciar casi la despensa: sin colchón no se mejora
	GameState.take_resource(&"wood", GameState.get_resource(&"wood"))
	GameState.add_resource(&"wood", 5)
	assert_false(site.upgrade_to_next(), "sin madera suficiente no mejora")
	assert_eq(site.recipe.id, &"choza", "sigue siendo choza")


func test_incomplete_house_does_not_upgrade() -> void:
	var site: ConstructionSite = _place_choza()
	await _tree_scene.process_frame
	assert_false(site.completed)
	assert_false(site.upgrade_to_next(), "una obra sin terminar no mejora")
