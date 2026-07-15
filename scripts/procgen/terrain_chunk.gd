class_name TerrainChunk
extends StaticBody3D
## Un trozo de mundo de CHUNK_SIZE×CHUNK_SIZE m (S1): malla y colisión
## muestreadas de WorldGen. La navegación la decide el ChunkManager
## (los chunks activos cuelgan de la NavigationRegion3D; los lejanos, no).

const CHUNK_SIZE: float = 64.0
const RESOLUTION: int = 64
## Espacio de IDs deterministas por chunk: los árboles nacen con el mismo
## ID exista el orden de activación que exista (clave del guardado).
const TREE_ID_BASE: int = 10_000_000
const TREE_ID_STRIDE: int = 2048
## Los IDs dinámicos (colonos, obras, campamentos) viven por encima.
const DYNAMIC_ID_FLOOR: int = 20_000_000

static var _grass_mesh: ArrayMesh
static var _grass_material: ShaderMaterial

var coord: Vector2i = Vector2i.ZERO
var populated: bool = false


static func create(world_gen: WorldGen, chunk_coord: Vector2i) -> TerrainChunk:
	var chunk: TerrainChunk = TerrainChunk.new()
	chunk.coord = chunk_coord
	chunk.name = "Chunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
	chunk.collision_layer = 1
	chunk.collision_mask = 0
	chunk.position = Vector3(
		(float(chunk_coord.x) + 0.5) * CHUNK_SIZE, 0.0, (float(chunk_coord.y) + 0.5) * CHUNK_SIZE
	)

	var side: int = RESOLUTION + 1
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(side * side)
	var step: float = CHUNK_SIZE / float(RESOLUTION)
	var origin_x: float = float(chunk_coord.x) * CHUNK_SIZE
	var origin_z: float = float(chunk_coord.y) * CHUNK_SIZE
	for iz: int in side:
		for ix: int in side:
			heights[iz * side + ix] = world_gen.height(
				origin_x + float(ix) * step, origin_z + float(iz) * step
			)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = _build_mesh(heights, side, step)
	mesh_instance.material_override = MapGenerator.terrain_material(PaletteData.get_default())
	chunk.add_child(mesh_instance)

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Collision"
	var shape: HeightMapShape3D = HeightMapShape3D.new()
	shape.map_width = side
	shape.map_depth = side
	shape.map_data = heights
	collision.shape = shape
	# HeightMapShape asume celda de 1 m: escalar al paso real del chunk.
	collision.scale = Vector3(step, 1.0, step)
	chunk.add_child(collision)
	return chunk


## Puebla el chunk con la vida de su bioma (Poisson local determinista):
## árboles con ID fijo por chunk, rocas, arbustos y flores.
func populate(world_gen: WorldGen) -> void:
	if populated:
		return
	populated = true
	var linear: int = (coord.x + 128) * 256 + (coord.y + 128)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = GameState.derive_seed(["chunk", coord.x, coord.y])
	var points: Array[Vector2] = Poisson.sample(Vector2(CHUNK_SIZE, CHUNK_SIZE), 4.4, rng)
	var origin_x: float = float(coord.x) * CHUNK_SIZE
	var origin_z: float = float(coord.y) * CHUNK_SIZE
	var tree_index: int = 0
	_build_water_blockers(world_gen, origin_x, origin_z)
	_plant_grass(world_gen, rng, origin_x, origin_z)
	for point: Vector2 in points:
		var x: float = origin_x + point.x
		var z: float = origin_z + point.y
		if not world_gen.is_inside(x, z, 2.0):
			continue
		var h: float = world_gen.height(x, z)
		# Nada brota sumergido (lagos e islas de la banda del cauce incluidos)
		if h < WorldGen.WATER_LEVEL + 0.15:
			continue
		var slope_x: float = world_gen.height(x + 1.0, z) - h
		var slope_z: float = world_gen.height(x, z + 1.0) - h
		if slope_x * slope_x + slope_z * slope_z > 0.16:
			continue
		var which: int = world_gen.biome(x, z)
		var roll: float = rng.randf()
		var density: float = world_gen.tree_density(which)
		if roll < 0.24 * density and tree_index < TREE_ID_STRIDE - 1:
			var tree: TreeEntity = TreeEntity.create(rng.randi(), rng.randf() < 0.25)
			tree.entity_id = TREE_ID_BASE + linear * TREE_ID_STRIDE + tree_index
			tree_index += 1
			EntityRegistry.register_with_id(tree, &"tree", tree.entity_id)
			tree.position = Vector3(x - position.x, h - 0.03, z - position.z)
			tree.rotation.y = rng.randf() * TAU
			tree.scale = Vector3.ONE * rng.randf_range(0.88, 1.12)
			add_child(tree)
		elif roll < 0.27:
			var rock: MeshInstance3D = PropGen.rock(rng.randi(), false)
			_place_local(rock, x, h - 0.06, z, rng)
		elif roll < 0.31 and which != WorldGen.Biome.COLINAS:
			_place_local(PropGen.bush(rng.randi()), x, h, z, rng)
		elif roll < 0.36 and (which == WorldGen.Biome.CLARO or which == WorldGen.Biome.PRADERA):
			_place_local(PropGen.flower_patch(rng.randi()), x, h, z, rng)
	EntityRegistry.reserve_below(DYNAMIC_ID_FLOOR)


## Hierba mecida (S1): matas instanciadas en UN draw call por chunk, con
## densidad por bioma, color variado y viento del shader de hierba.
func _plant_grass(
	world_gen: WorldGen, rng: RandomNumberGenerator, origin_x: float, origin_z: float
) -> void:
	var palette: PaletteData = PaletteData.get_default()
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for _i: int in 900:
		var x: float = origin_x + rng.randf() * CHUNK_SIZE
		var z: float = origin_z + rng.randf() * CHUNK_SIZE
		if not world_gen.is_inside(x, z, 2.0):
			continue
		var which: int = world_gen.biome(x, z)
		var density: float = 1.0
		match which:
			WorldGen.Biome.BOSQUE:
				density = 0.45
			WorldGen.Biome.COLINAS:
				density = 0.35
			WorldGen.Biome.RIBERA:
				density = 0.7
		if rng.randf() > density:
			continue
		var h: float = world_gen.height(x, z)
		if h < WorldGen.WATER_LEVEL + 0.2:
			continue
		var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.scaled(Vector3.ONE * rng.randf_range(0.7, 1.25))
		transforms.append(Transform3D(basis, Vector3(x - position.x, h - 0.01, z - position.z)))
		colors.append(palette.grass.lerp(palette.grass_light, rng.randf()))
	if transforms.is_empty():
		return
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _tuft_mesh()
	multi.instance_count = transforms.size()
	for i: int in transforms.size():
		multi.set_instance_transform(i, transforms[i])
		multi.set_instance_color(i, colors[i])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "Grass"
	instance.multimesh = multi
	instance.material_override = _grass_mat()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


static func _tuft_mesh() -> ArrayMesh:
	if _grass_mesh != null:
		return _grass_mesh
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	# Dos quads cruzados, afilados hacia arriba (mata de hierba de cuento)
	for quad: int in 2:
		var dir: Vector3 = Vector3(1, 0, 0) if quad == 0 else Vector3(0, 0, 1)
		var base_i: int = verts.size()
		(
			verts
			. append_array(
				[
					-dir * 0.11,
					dir * 0.11,
					dir * 0.035 + Vector3(0, 0.45, 0),
					-dir * 0.035 + Vector3(0, 0.45, 0),
				]
			)
		)
		for _v: int in 4:
			normals.append(Vector3.UP)
		indices.append_array([base_i, base_i + 1, base_i + 2, base_i, base_i + 2, base_i + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	_grass_mesh = ArrayMesh.new()
	_grass_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _grass_mesh


static func _grass_mat() -> ShaderMaterial:
	if _grass_material != null:
		return _grass_material
	_grass_material = ShaderMaterial.new()
	_grass_material.shader = load("res://shaders/grass.gdshader")
	return _grass_material


## El agua profunda NO se cruza (orden del dueño): cajas invisibles en la
## capa de horneado sobre las celdas de cauce — el navmesh las esquiva y
## los ríos son fronteras reales hasta que se descubran los puentes.
func _build_water_blockers(world_gen: WorldGen, origin_x: float, origin_z: float) -> void:
	var blockers: StaticBody3D = StaticBody3D.new()
	blockers.name = "WaterBlockers"
	blockers.collision_layer = 1 << 5
	blockers.collision_mask = 0
	# Celda de 2 m y umbral 0.30: MURO continuo sobre el cauce (con 4 m
	# quedaban huecos diagonales y el navmesh cruzaba el río).
	var cell: float = 2.0
	var cells: int = int(CHUNK_SIZE / cell)
	var any: bool = false
	for iz: int in cells:
		for ix: int in cells:
			var cx: float = origin_x + (float(ix) + 0.5) * cell
			var cz: float = origin_z + (float(iz) + 0.5) * cell
			if world_gen.river_mask(cx, cz) < 0.30:
				continue
			any = true
			var shape: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(cell, 4.0, cell)
			shape.shape = box
			shape.position = Vector3(cx - position.x, WorldGen.WATER_LEVEL + 0.6, cz - position.z)
			blockers.add_child(shape)
	if any:
		add_child(blockers)
	else:
		blockers.free()


func _place_local(node: Node3D, x: float, h: float, z: float, rng: RandomNumberGenerator) -> void:
	node.position = Vector3(x - position.x, h, z - position.z)
	node.rotation.y = rng.randf() * TAU
	node.scale = Vector3.ONE * rng.randf_range(0.88, 1.12)
	add_child(node)


static func _build_mesh(heights: PackedFloat32Array, side: int, step: float) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	verts.resize(side * side)
	normals.resize(side * side)
	colors.resize(side * side)
	var half: float = float(side - 1) * step * 0.5
	for iz: int in side:
		for ix: int in side:
			var idx: int = iz * side + ix
			verts[idx] = Vector3(float(ix) * step - half, heights[idx], float(iz) * step - half)
			var hl: float = heights[iz * side + clampi(ix - 1, 0, side - 1)]
			var hr: float = heights[iz * side + clampi(ix + 1, 0, side - 1)]
			var hd: float = heights[clampi(iz - 1, 0, side - 1) * side + ix]
			var hu: float = heights[clampi(iz + 1, 0, side - 1) * side + ix]
			normals[idx] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
			colors[idx] = Color(0.0, 0.0, 0.0)
	for iz: int in side - 1:
		for ix: int in side - 1:
			var i00: int = iz * side + ix
			var i10: int = iz * side + ix + 1
			var i01: int = (iz + 1) * side + ix
			var i11: int = (iz + 1) * side + ix + 1
			# Winding horario visto desde arriba (cara frontal en Godot)
			indices.append_array([i00, i10, i01, i10, i11, i01])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
