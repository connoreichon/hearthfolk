extends HFTestCase
## S1: los chunks cuentan la MISMA altura que WorldGen (sin costuras entre
## vecinos) y el gestor activa exactamente los trozos que pisan el mapa.

var _root: Node3D


func before_each() -> void:
	_root = Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_root)


func after_each() -> void:
	_root.free()


func test_chunk_heights_match_world_gen() -> void:
	var world_gen: WorldGen = WorldGen.new(777)
	var chunk: TerrainChunk = TerrainChunk.create(world_gen, Vector2i(-1, 0))
	_root.add_child(chunk)
	var shape: HeightMapShape3D = (chunk.get_node("Collision") as CollisionShape3D).shape
	var side: int = TerrainChunk.RESOLUTION + 1
	assert_eq(shape.map_width, side, "resolución de colisión")
	# Cuatro puntos internos: la altura del muestreo == WorldGen directo
	for probe: Vector2 in [Vector2(-60, 10), Vector2(-33, 33), Vector2(-1, 63), Vector2(-64, 0)]:
		var idx_x: int = int(round(probe.x - float(chunk.coord.x) * TerrainChunk.CHUNK_SIZE))
		var idx_z: int = int(round(probe.y - float(chunk.coord.y) * TerrainChunk.CHUNK_SIZE))
		if idx_x < 0 or idx_x >= side or idx_z < 0 or idx_z >= side:
			continue
		assert_almost_eq(
			shape.map_data[idx_z * side + idx_x],
			world_gen.height(probe.x, probe.y),
			0.001,
			"altura fiel en %s" % probe
		)


func test_neighbour_chunks_share_seam() -> void:
	var world_gen: WorldGen = WorldGen.new(4242)
	var left: TerrainChunk = TerrainChunk.create(world_gen, Vector2i(-1, 0))
	var right: TerrainChunk = TerrainChunk.create(world_gen, Vector2i(0, 0))
	_root.add_child(left)
	_root.add_child(right)
	var side: int = TerrainChunk.RESOLUTION + 1
	var shape_l: HeightMapShape3D = (left.get_node("Collision") as CollisionShape3D).shape
	var shape_r: HeightMapShape3D = (right.get_node("Collision") as CollisionShape3D).shape
	for iz: int in [0, 16, 32, 48, 64]:
		assert_almost_eq(
			shape_l.map_data[iz * side + (side - 1)],
			shape_r.map_data[iz * side + 0],
			0.0001,
			"costura idéntica en fila %d" % iz
		)


func test_manager_activates_around_points() -> void:
	var world_gen: WorldGen = WorldGen.new(777)
	var manager: ChunkManager = ChunkManager.new()
	manager.world_gen = world_gen
	manager.nav_parent = _root
	_root.add_child(manager)
	var created: int = manager.ensure_active_around(Vector3.ZERO, 64.0)
	assert_eq(created, 4, "radio 64 en el origen: 2×2 chunks (mapa de 120)")
	assert_eq(manager.ensure_active_around(Vector3.ZERO, 64.0), 0, "idempotente")
	assert_true(manager.chunk_at(Vector2i(-1, -1)) != null, "chunk NW vivo")
	# Fuera del mapa jugable no se crean chunks
	var far: int = manager.ensure_active_around(Vector3(4000.0, 0.0, 4000.0), 64.0)
	assert_eq(far, 0, "más allá del borde del mapa no nace nada")
