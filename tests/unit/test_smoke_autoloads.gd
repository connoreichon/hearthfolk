extends HFTestCase
## Sonda P0: los autoloads existen y responden.


func test_autoloads_exist() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "main loop debe ser SceneTree")
	for autoload_name: String in [
		"EventBus",
		"SimClock",
		"GameState",
		"TaskBoard",
		"EntityRegistry",
		"SaveManager",
		"AudioDirector",
		"DebugOverlay",
	]:
		assert_true(tree.root.has_node(autoload_name), "falta autoload " + autoload_name)


func test_sim_clock_constants() -> void:
	assert_almost_eq(SimClock.TICK_DT, 0.05)
	assert_eq(SimClock.Speed.ULTRA, 4)
