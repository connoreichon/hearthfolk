extends HFTestCase
## Integración P2: 4 habitantes aparecen, deambulan y no se atraviesan.


func test_citizens_spawn_and_wander() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	GameState.setup_new_game(4242)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	SimClock.reset()
	SimClock.set_speed(4)
	for _f: int in 30:
		await tree.process_frame

	var citizens: Array[Node] = tree.get_nodes_in_group(&"citizens")
	assert_eq(citizens.size(), 4, "deben aparecer 4 habitantes")
	var start_positions: Array[Vector3] = []
	for citizen: Node in citizens:
		start_positions.append((citizen as Node3D).global_position)

	for _f: int in 420:
		await tree.process_frame

	var moved: int = 0
	for i: int in citizens.size():
		var citizen: Node3D = citizens[i] as Node3D
		var pos: Vector3 = citizen.global_position
		assert_true(is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z), "posición finita")
		if pos.distance_to(start_positions[i]) > 0.8:
			moved += 1
	assert_true(moved >= 3, "al menos 3 de 4 habitantes se han movido (%d)" % moved)

	for i: int in citizens.size():
		for j: int in range(i + 1, citizens.size()):
			var d: float = (citizens[i] as Node3D).global_position.distance_to(
				(citizens[j] as Node3D).global_position
			)
			assert_true(d > 0.22, "habitantes %d y %d no se atraviesan (d=%f)" % [i, j, d])

	main.free()
	SimClock.set_speed(1)
	SimClock.reset()
	GameState.world_seed = 0
	GameState.terrain = null
	EntityRegistry.clear()
