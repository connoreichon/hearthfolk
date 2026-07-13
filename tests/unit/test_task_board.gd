extends HFTestCase
## TaskBoard: claim atómico, TTL, blacklist, purga de targets muertos.

var board: Node


func before_each() -> void:
	board = (load("res://autoload/task_board.gd") as GDScript).new()
	SimClock.elapsed_sim_seconds = 0.0


func after_each() -> void:
	board.free()
	EntityRegistry.clear()


func test_claim_is_atomic() -> void:
	var task_id: int = board.publish(&"chop", 0, {}, 5)
	assert_true(board.claim(task_id, 1), "primera reclamación debe funcionar")
	assert_false(board.claim(task_id, 2), "segunda reclamación debe fallar")
	board.release(task_id, 1, &"yield")
	assert_true(board.claim(task_id, 2), "tras liberar, otro puede reclamar")


func test_ttl_releases_claim() -> void:
	var task_id: int = board.publish(&"haul", 0, {}, 5)
	assert_true(board.claim(task_id, 7))
	SimClock.elapsed_sim_seconds = 46.0
	board._on_sim_tick(0.05)
	var task: Variant = board.get_task(task_id)
	assert_eq(task.claimed_by, -1, "TTL vencido debe liberar la tarea")


func test_blacklist_after_three_failures() -> void:
	var task_id: int = board.publish(&"chop", 0, {}, 5)
	for _round: int in 3:
		assert_true(board.claim(task_id, 3))
		board.release(task_id, 3, &"stuck")
		SimClock.elapsed_sim_seconds += 25.0
	assert_false(board.claim(task_id, 3), "tras 3 fallos, el habitante queda vetado")
	assert_true(board.claim(task_id, 4), "otro habitante sí puede")


func test_cooldown_after_three_failures() -> void:
	SimClock.elapsed_sim_seconds = 100.0
	var task_id: int = board.publish(&"chop", 0, {}, 5)
	for _round: int in 3:
		assert_true(board.claim(task_id, 3))
		board.release(task_id, 3, &"stuck")
	assert_false(board.claim(task_id, 5), "en cooldown nadie reclama")
	SimClock.elapsed_sim_seconds = 121.0
	assert_true(board.claim(task_id, 5), "pasado el cooldown, libre")


func test_dead_target_purges_task() -> void:
	var node: Node3D = Node3D.new()
	var entity_id: int = EntityRegistry.register(node, &"tree")
	var task_id: int = board.publish(&"chop", entity_id, {}, 5)
	board._on_sim_tick(0.05)
	assert_ne(board.get_task(task_id), null, "target vivo, tarea viva")
	EntityRegistry.unregister(entity_id)
	board._on_sim_tick(0.05)
	assert_eq(board.get_task(task_id), null, "target muerto, tarea purgada")
	node.free()


func test_best_task_prefers_priority_then_distance() -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var near: Node3D = Node3D.new()
	var far: Node3D = Node3D.new()
	root.add_child(near)
	root.add_child(far)
	near.global_position = Vector3(1.0, 0.0, 0.0)
	far.global_position = Vector3(50.0, 0.0, 0.0)
	var near_id: int = EntityRegistry.register(near, &"tree")
	var far_id: int = EntityRegistry.register(far, &"tree")
	var low_priority_near: int = board.publish(&"chop", near_id, {}, 5)
	var high_priority_far: int = board.publish(&"chop", far_id, {}, 1)
	var best: Variant = board.best_task_for(1, Vector3.ZERO)
	assert_eq(best.id, high_priority_far, "prioridad manda sobre distancia")
	board.cancel(high_priority_far)
	best = board.best_task_for(1, Vector3.ZERO)
	assert_eq(best.id, low_priority_near)
	near.free()
	far.free()
