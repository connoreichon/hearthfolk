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
	# Este test cuenta EXACTAMENTE 6 maderas: se despeja el territorio del
	# campamento para que la auto-tala no tenga qué marcar (la vida
	# emergente añadía leña extra y rompía el conteo).
	var camp: CampEntity = _tree_scene.get_nodes_in_group(&"camps")[0] as CampEntity
	for node: Node in _tree_scene.get_nodes_in_group(&"trees"):
		var tree: Node3D = node as Node3D
		var dist: float = tree.global_position.distance_to(camp.global_position)
		if dist < CampEntity.TERRITORY_RADIUS + 2.0:
			tree.free()
	# Determinismo (M0): este test va de ACARREO, no del crafteo de S2 —
	# los fundadores llegan con herramientas para no gastar ventana tallando.
	for node: Node in _tree_scene.get_nodes_in_group(&"citizens"):
		(node as Citizen).data.has_tools = true


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
	# Sembrar 3 haces (6 unidades) alrededor del CAMPAMENTO, como tras una
	# tala (en el mundo gigante el campamento puede no estar en el origen)
	var world: Node3D = _main.get_node("World") as Node3D
	var parent: Node3D = world.get_node("NavigationRegion3D") as Node3D
	var home: Vector3 = (_tree_scene.get_nodes_in_group(&"camps")[0] as Node3D).global_position
	for i: int in 3:
		var item: ResourceItem = ResourceItem.create(&"wood", 2, 100 + i)
		parent.add_child(item)
		var ang: float = TAU * float(i) / 3.0
		var pos: Vector3 = home + Vector3(cos(ang) * 7.0, 0.0, sin(ang) * 7.0)
		pos.y = GameState.terrain.get_height(pos.x, pos.z)
		item.global_position = pos
	assert_eq(GameState.get_resource(&"wood"), 0)

	var done: bool = false
	for _f: int in 6400:
		await _tree_scene.process_frame
		if (
			GameState.get_resource(&"wood") == 6
			and _tree_scene.get_nodes_in_group(&"resources").is_empty()
		):
			done = true
			break
	assert_true(done, "toda la madera llega al almacén (wood=%d)" % GameState.get_resource(&"wood"))
	assert_eq(GameState.get_resource(&"wood"), 6, "sin duplicados: exactamente 6")
	# Settle (M0): el free del último item y su baja del registro pueden
	# cruzar un frame — se espera la condición, no un instante exacto.
	var registry_clear: bool = false
	for _f: int in 300:
		await _tree_scene.process_frame
		if EntityRegistry.all_of_kind(&"resource").is_empty():
			registry_clear = true
			break
	assert_true(registry_clear, "sin items huérfanos registrados")
