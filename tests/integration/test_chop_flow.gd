extends HFTestCase
## Integración P4: árbol marcado → habitante lo tala → 6 unidades en el suelo.

var _main: Node
var _tree_scene: SceneTree


func before_each() -> void:
	_tree_scene = Engine.get_main_loop() as SceneTree
	GameState.setup_new_game(2222)
	GameState.add_resource(&"food", 12)
	# Despensa de leña llena: la auto-tala del campamento no interfiere
	GameState.add_resource(&"wood", 24)
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


func test_marked_tree_is_chopped_and_drops_wood() -> void:
	for _f: int in 20:
		await _tree_scene.process_frame
	var target: TreeEntity = _nearest_adult_tree()
	assert_true(target != null, "hay árbol adulto")
	var tree_id: int = target.entity_id
	target.set_marked(true)
	assert_true(target.marked)
	TaskBoard.publish(&"chop", tree_id, {}, 5)

	var wood_units: int = 0
	for _f: int in 2600:
		await _tree_scene.process_frame
		wood_units = _wood_on_ground()
		if wood_units >= 6 and EntityRegistry.get_node_by_id(tree_id) == null:
			break
	assert_eq(wood_units, 6, "el árbol rinde 6 unidades de madera en el suelo")
	assert_eq(
		EntityRegistry.get_node_by_id(tree_id), null, "el árbol talado desaparece del registro"
	)
	assert_eq(EntityRegistry.all_of_kind(&"stump").size(), 1, "queda un tocón persistente")
	assert_eq(
		TaskBoard.first_task_for_target(tree_id, &"chop"), null, "la tarea chop se ha purgado"
	)


func test_no_double_claim_on_same_tree() -> void:
	for _f: int in 20:
		await _tree_scene.process_frame
	var target: TreeEntity = _nearest_adult_tree()
	target.set_marked(true)
	var task_id: int = TaskBoard.publish(&"chop", target.entity_id, {}, 5)
	for _f: int in 200:
		await _tree_scene.process_frame
		var task: TaskBoard.Task = TaskBoard.get_task(task_id)
		if task == null:
			break
		var claimed: int = 0
		for citizen: Node in _tree_scene.get_nodes_in_group(&"citizens"):
			if (citizen as Citizen).current_task_id == task_id:
				claimed += 1
		assert_true(claimed <= 1, "nunca dos habitantes con la misma tarea")


func _nearest_adult_tree() -> TreeEntity:
	var best: TreeEntity = null
	var best_d: float = INF
	for node: Node in _tree_scene.get_nodes_in_group(&"trees"):
		var tree: TreeEntity = node as TreeEntity
		# Sin marcar: la auto-tala del campamento puede haber madrugado, y
		# marcar dos veces el mismo árbol duplicaría la tarea (como la T
		# del jugador, que también ignora los ya marcados).
		if tree == null or tree.marked or not tree.choppable():
			continue
		var d: float = tree.global_position.length()
		if d < best_d:
			best_d = d
			best = tree
	return best


func _wood_on_ground() -> int:
	var total: int = 0
	for node: Node in _tree_scene.get_nodes_in_group(&"resources"):
		total += (node as ResourceItem).amount
	return total
