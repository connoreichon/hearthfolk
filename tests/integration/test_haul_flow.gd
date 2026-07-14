extends HFTestCase
## Integración P5: la madera del suelo acaba en el almacén sin duplicados.

var _main: Node
var _tree_scene: SceneTree


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	GameState.setup_new_game(2222)
	GameState.add_resource(&"food", 12)
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	_tree_scene.root.add_child(_main)
	SimClock.reset(1, 0.3)
	SimClock.set_speed(4)


func after_each() -> void:
	_main.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
	TaskBoard.clear()


func test_ground_wood_ends_in_storage_without_duplicates() -> void:
	for _f: int in 20:
		await _tree_scene.process_frame
	# Sembrar 3 haces (6 unidades) cerca del centro, como tras una tala
	var world: Node3D = _main.get_node("World") as Node3D
	var parent: Node3D = world.get_node("NavigationRegion3D") as Node3D
	for i: int in 3:
		var item: ResourceItem = ResourceItem.create(&"wood", 2, 100 + i)
		parent.add_child(item)
		var ang: float = TAU * float(i) / 3.0
		var pos: Vector3 = Vector3(cos(ang) * 7.0, 0.0, sin(ang) * 7.0)
		pos.y = GameState.terrain.get_height(pos.x, pos.z)
		item.global_position = pos
	assert_eq(GameState.get_resource(&"wood"), 0)

	var done: bool = false
	for _f: int in 4200:
		await _tree_scene.process_frame
		if (
			GameState.get_resource(&"wood") == 6
			and _tree_scene.get_nodes_in_group(&"resources").is_empty()
		):
			done = true
			break
	assert_true(done, "toda la madera llega al almacén (wood=%d)" % GameState.get_resource(&"wood"))
	assert_eq(GameState.get_resource(&"wood"), 6, "sin duplicados: exactamente 6")
	assert_eq(EntityRegistry.all_of_kind(&"resource").size(), 0, "sin items huérfanos registrados")
