extends HFTestCase
## Q0: flujo menú→partida nueva→guardar en slot→cargar desde slot.

const GAME_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

var _tree_scene: SceneTree


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	SimClock.set_speed(0)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()


func after_each() -> void:
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.pending_new_seed = 0
	GameState.pending_load_slot = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()
	SaveManager.active_slot = 1


func test_slot_paths_are_distinct() -> void:
	assert_ne(SaveManager.slot_path(1), SaveManager.slot_path(2))
	assert_ne(SaveManager.slot_path(2), SaveManager.slot_path(3))


func test_new_game_save_and_load_via_slot() -> void:
	# «Nueva partida» desde el menú: semilla 777 en el slot 2
	GameState.pending_new_seed = 777
	SaveManager.active_slot = 2
	var game: Node = GAME_SCENE.instantiate()
	_tree_scene.root.add_child(game)
	for _f: int in 10:
		await _tree_scene.process_frame
	assert_eq(GameState.world_seed, 777, "la semilla del menú manda")
	assert_eq(GameState.pending_new_seed, 0, "la intención se consume")
	assert_eq(GameState.get_resource(&"food"), 12, "arranque de partida nueva")
	GameState.add_resource(&"wood", 7)
	SaveManager.save_game()
	assert_true(SaveManager.has_save(2), "guardado en el slot 2")
	assert_true("Día" in SaveManager.slot_summary(2), "resumen de slot legible")
	game.free()
	EntityRegistry.clear()
	TaskBoard.clear()

	# «Cargar partida» desde el menú: slot 2
	GameState.world_seed = 0
	GameState.pending_load_slot = 2
	var game2: Node = GAME_SCENE.instantiate()
	_tree_scene.root.add_child(game2)
	for _f: int in 20:
		await _tree_scene.process_frame
	assert_eq(GameState.world_seed, 777, "semilla restaurada del slot 2")
	assert_eq(GameState.get_resource(&"wood"), 7, "inventario restaurado del slot 2")
	assert_eq(_tree_scene.get_nodes_in_group(&"citizens").size(), 4)
	game2.free()
