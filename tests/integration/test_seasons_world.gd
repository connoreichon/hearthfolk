extends HFTestCase
## Q1: en el mundo real, el invierno nieva, la primavera hace crecer los
## brotes y el otoño siembra nuevos.

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
	RenderingServer.global_shader_parameter_set(&"snow_amount", 0.0)


func test_winter_brings_snow_and_spring_grows_saplings() -> void:
	for _f: int in 10:
		await _tree_scene.process_frame
	var young_before: int = _count_young()
	assert_true(young_before > 0, "hay brotes al empezar")

	# Avanzar al otoño (día 5): siembra de brotes
	var trees_before: int = _tree_scene.get_nodes_in_group(&"trees").size()
	while SimClock.get_season() != SimClock.Season.AUTUMN:
		SimClock.advance_hours(24.0)
	await _tree_scene.process_frame
	var trees_autumn: int = _tree_scene.get_nodes_in_group(&"trees").size()
	assert_true(trees_autumn >= trees_before, "el otoño no destruye árboles")

	# Invierno: nieve global > 0 tras la transición (blend gradual ~8 s)
	while SimClock.get_season() != SimClock.Season.WINTER:
		SimClock.advance_hours(24.0)
	var controller: SeasonController = _main.get_node("World/SeasonController")
	for _f: int in 1200:
		await _tree_scene.process_frame
		if controller.snow_level() > 0.2:
			break
	assert_true(
		controller.snow_level() > 0.2, "nieve activa en invierno (%.2f)" % controller.snow_level()
	)

	# Primavera del año 2: los brotes se hacen adultos
	while SimClock.get_season() != SimClock.Season.SPRING:
		SimClock.advance_hours(24.0)
	await _tree_scene.process_frame
	assert_eq(SimClock.get_year(), 2, "primavera del año 2")
	assert_eq(_count_young(), 0, "todos los brotes crecieron en primavera")


func _count_young() -> int:
	var count: int = 0
	for node: Node in _tree_scene.get_nodes_in_group(&"trees"):
		var tree: TreeEntity = node as TreeEntity
		if tree != null and tree.young and not tree.felled:
			count += 1
	return count
