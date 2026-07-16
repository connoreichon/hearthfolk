extends HFTestCase
## S1: WorldGen determinista a escala gigante, red de ríos real, y chunks
## que pueblan su bioma con IDs de árbol fijos (independientes del orden
## de activación — la clave del guardado v2).

var _root: Node3D


func before_each() -> void:
	GameState.setup_new_game(999)
	_root = Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_root)


func after_each() -> void:
	_root.free()
	EntityRegistry.clear()
	GameState.world_seed = 0
	GameState.terrain = null
	GameState.world_gen = null


func test_world_gen_is_deterministic_and_bounded() -> void:
	var gen_a: WorldGen = WorldGen.new(777)
	var gen_b: WorldGen = WorldGen.new(777)
	var gen_c: WorldGen = WorldGen.new(778)
	assert_eq(gen_a.map_half, WorldGen.DEFAULT_HALF, "mapa gigante por defecto")
	var any_diff: bool = false
	for probe: Vector2 in [
		Vector2(0, 0),
		Vector2(400, -380),
		Vector2(-500, 500),
		Vector2(123, 321),
		Vector2(-77, -240),
	]:
		var h: float = gen_a.height(probe.x, probe.y)
		assert_almost_eq(h, gen_b.height(probe.x, probe.y), 0.0001, "altura fiel en %s" % probe)
		assert_true(h >= -1.8 and h <= 18.0, "altura acotada en %s" % probe)
		assert_eq(gen_a.biome(probe.x, probe.y), gen_b.biome(probe.x, probe.y), "mismo bioma")
		if absf(h - gen_c.height(probe.x, probe.y)) > 0.01:
			any_diff = true
	assert_true(any_diff, "semilla distinta, mundo distinto")


func test_river_network_exists() -> void:
	var gen: WorldGen = WorldGen.new(777)
	var water_points: int = 0
	var biomes_seen: Dictionary = {}
	for gx: int in range(-256, 257, 16):
		for gz: int in range(-256, 257, 16):
			biomes_seen[gen.biome(float(gx), float(gz))] = true
			if gen.is_water(float(gx), float(gz)):
				water_points += 1
				assert_true(
					gen.height(float(gx), float(gz)) < WorldGen.WATER_LEVEL + 0.15,
					"el cauce se hunde bajo el nivel del agua en %d,%d" % [gx, gz]
				)
	assert_true(water_points >= 3, "hay red de ríos (%d puntos de agua)" % water_points)
	assert_true(biomes_seen.size() >= 3, "variedad de biomas (%d)" % biomes_seen.size())


func test_chunk_population_has_deterministic_tree_ids() -> void:
	var gen: WorldGen = WorldGen.new(GameState.derive_seed(["map"]))
	var chunk_a: TerrainChunk = TerrainChunk.create(gen, Vector2i(0, 0))
	_root.add_child(chunk_a)
	chunk_a.populate(gen)
	var trees_a: Dictionary = {}
	for node: Node in chunk_a.get_children():
		if node is TreeEntity:
			trees_a[(node as TreeEntity).entity_id] = (node as Node3D).position
	chunk_a.free()
	EntityRegistry.clear()

	var chunk_b: TerrainChunk = TerrainChunk.create(gen, Vector2i(0, 0))
	_root.add_child(chunk_b)
	chunk_b.populate(gen)
	var trees_b: Dictionary = {}
	for node: Node in chunk_b.get_children():
		if node is TreeEntity:
			trees_b[(node as TreeEntity).entity_id] = (node as Node3D).position
	assert_true(trees_a.size() > 0, "el chunk del origen tiene árboles")
	assert_eq(trees_b.size(), trees_a.size(), "misma población al repoblar")
	for tree_id: int in trees_a:
		assert_true(tree_id >= TerrainChunk.TREE_ID_BASE, "ID en el espacio determinista")
		assert_true(trees_b.has(tree_id), "árbol %d renace con el mismo ID" % tree_id)
	# El siguiente ID dinámico queda por encima del espacio de los chunks
	var probe: Node = Node.new()
	var probe_id: int = EntityRegistry.register(probe, &"probe")
	assert_true(probe_id >= TerrainChunk.DYNAMIC_ID_FLOOR, "dinámicos sobre el suelo reservado")
	probe.free()
