extends HFTestCase
## S2 adelantada: el campamento se procura su propia leña — marca árboles
## de su territorio sin que el jugador toque la T, respetando la reserva
## objetivo y la prioridad del jugador (0 = máxima; auto-tala = 6).

const GAME_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

var _main: Node
var _tree_scene: SceneTree


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	GameState.setup_new_game(4444)
	GameState.add_resource(&"food", 12)
	_main = GAME_SCENE.instantiate()
	_tree_scene.root.add_child(_main)
	SimClock.reset(1, 0.3)
	SimClock.set_speed(4)
	for _f: int in 10:
		await _tree_scene.process_frame


func after_each() -> void:
	_main.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.terrain = null
	GameState.world_gen = null
	EntityRegistry.clear()
	TaskBoard.clear()


func test_camp_marks_trees_for_wood() -> void:
	assert_eq(GameState.get_resource(&"wood"), 0, "sin leña al empezar")
	var marked: TreeEntity = null
	for _f: int in 1400:
		await _tree_scene.process_frame
		for node: Node in _tree_scene.get_nodes_in_group(&"trees"):
			var tree: TreeEntity = node as TreeEntity
			if tree != null and tree.marked:
				marked = tree
				break
		if marked != null:
			break
	assert_true(marked != null, "el campamento marca un árbol solo")
	var camp: CampEntity = _tree_scene.get_nodes_in_group(&"camps")[0] as CampEntity
	assert_true(
		(
			marked.global_position.distance_to(camp.global_position)
			<= CampEntity.TERRITORY_RADIUS + 1.0
		),
		"el árbol marcado es de SU territorio"
	)
	var task: TaskBoard.Task = TaskBoard.first_task_for_target(marked.entity_id, &"chop")
	assert_true(task != null, "la tala entra al tablón")
	assert_eq(task.priority, 7, "prioridad más débil que las órdenes del jugador")
	assert_eq(int(task.payload.get("band", -99)), camp.band_id, "la tarea lleva la banda")
	var stranger: TaskBoard.Task = TaskBoard.best_task_for(
		999999, marked.global_position, [&"chop"], camp.band_id + 7
	)
	assert_true(stranger == null, "un colono de OTRA banda no puede reclamarla")
	var local: TaskBoard.Task = TaskBoard.best_task_for(
		999999, marked.global_position, [&"chop"], camp.band_id
	)
	assert_true(local != null, "un colono de SU banda sí")


func test_wander_stays_near_home_camp() -> void:
	var camp: CampEntity = _tree_scene.get_nodes_in_group(&"camps")[0] as CampEntity
	var citizen: Citizen = _tree_scene.get_nodes_in_group(&"citizens")[0] as Citizen
	citizen.state_machine.change(&"Wander")
	await _tree_scene.process_frame
	var target: Vector3 = citizen.nav_agent.target_position
	assert_true(
		(
			Vector2(target.x, target.z).distance_to(
				Vector2(camp.global_position.x, camp.global_position.z)
			)
			< 24.0
		),
		"el paseo orbita SU hoguera (forrajeo incluido), no el centro del mundo"
	)
