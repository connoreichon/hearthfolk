class_name TerrainChunk
extends StaticBody3D
## Un trozo de mundo de CHUNK_SIZE×CHUNK_SIZE m (S1): malla y colisión
## muestreadas de WorldGen. La navegación la decide el ChunkManager
## (los chunks activos cuelgan de la NavigationRegion3D; los lejanos, no).

const CHUNK_SIZE: float = 64.0
const RESOLUTION: int = 64

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
