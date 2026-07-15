extends HFTestCase
## MapGenerator: misma semilla → mismo mapa; conteos exactos de props (§4).


func after_each() -> void:
	EntityRegistry.clear()


func test_same_seed_same_heights() -> void:
	var t1: TerrainData = MapGenerator.build_terrain_data(777)
	var t2: TerrainData = MapGenerator.build_terrain_data(777)
	var t3: TerrainData = MapGenerator.build_terrain_data(778)
	assert_true(t1.heights == t2.heights, "misma semilla, mismas alturas")
	assert_true(t1.heights != t3.heights, "semilla distinta, alturas distintas")


func test_height_limits_and_flat_center() -> void:
	var terrain: TerrainData = MapGenerator.build_terrain_data(777)
	var max_h: float = -100.0
	var min_h: float = 100.0
	for h: float in terrain.heights:
		max_h = maxf(max_h, h)
		min_h = minf(min_h, h)
	assert_true(max_h <= 4.0, "desnivel máximo 4 m (max=%f)" % max_h)
	assert_true(min_h >= -1.6, "cauce limitado (min=%f)" % min_h)
	for probe: Vector2 in [Vector2(0, 0), Vector2(10, 5), Vector2(-12, 8), Vector2(5, -15)]:
		var slope: float = terrain.get_slope_deg(probe.x, probe.y)
		assert_true(slope < 3.0, "centro casi plano en %s (%f°)" % [probe, slope])


func test_prop_counts_and_determinism() -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var parent1: Node3D = Node3D.new()
	root.add_child(parent1)
	var result1: Dictionary = MapGenerator.generate(parent1, 999)
	var counts: Dictionary = result1["counts"]
	assert_eq(int(counts["trees_adult"]), 34)
	assert_eq(int(counts["trees_young"]), 12)
	assert_eq(int(counts["rocks_big"]), 4)
	assert_eq(int(counts["rocks_small"]), 14)
	assert_eq(int(counts["flowers"]), 6)
	assert_eq(int(counts["bushes"]), 8)
	# Build 003: el mapa base ya no trae fogata ni carro (los funda cada
	# banda vía CampEntity), así que no hay conteos que comprobar aquí.
	assert_false(counts.has("campfire"), "el mapa base no coloca fogata")
	assert_false(counts.has("cart"), "el mapa base no coloca carro")
	var trees1: Array[Vector3] = _tree_positions(parent1)
	parent1.free()
	EntityRegistry.clear()

	var parent2: Node3D = Node3D.new()
	root.add_child(parent2)
	var result2: Dictionary = MapGenerator.generate(parent2, 999)
	assert_eq(result2["counts"], counts, "conteos idénticos con la misma semilla")
	var trees2: Array[Vector3] = _tree_positions(parent2)
	parent2.free()

	assert_eq(trees1.size(), trees2.size())
	for i: int in trees1.size():
		assert_true(trees1[i].is_equal_approx(trees2[i]), "árbol %d en la misma posición" % i)


func _tree_positions(parent: Node3D) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var props: Node3D = parent.get_node("Props") as Node3D
	for child: Node in props.get_children():
		if child is TreeEntity:
			positions.append((child as Node3D).position)
	return positions
