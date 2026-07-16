class_name FarTerrain
extends Node3D
## Terreno LEJANO del mapa gigante (S1): parches visuales de baja
## resolución que cubren TODO el mundo desde el primer frame — para elegir
## dónde sembrar, y para que el horizonte sea continente y no vacío.
## Sin colisión ni props; cuando un chunk real se activa, su parche se
## oculta (el detalle manda). Ligeramente hundido para evitar z-fighting.

const PATCH_DIVISIONS: int = 8
const SINK: float = 0.12

var _patches: Dictionary = {}


static func create(world_gen: WorldGen) -> FarTerrain:
	var far: FarTerrain = FarTerrain.new()
	far.name = "FarTerrain"
	var material: ShaderMaterial = MapGenerator.terrain_material(PaletteData.get_default())
	var chunks_per_side: int = int(ceil(world_gen.map_half * 2.0 / TerrainChunk.CHUNK_SIZE))
	var first: int = -chunks_per_side / 2
	for cz: int in range(first, first + chunks_per_side):
		for cx: int in range(first, first + chunks_per_side):
			var coord: Vector2i = Vector2i(cx, cz)
			var patch: MeshInstance3D = MeshInstance3D.new()
			patch.name = "Far_%d_%d" % [cx, cz]
			patch.mesh = _build_patch(world_gen, coord)
			patch.material_override = material
			patch.position = Vector3(
				(float(cx) + 0.5) * TerrainChunk.CHUNK_SIZE,
				-SINK,
				(float(cz) + 0.5) * TerrainChunk.CHUNK_SIZE
			)
			far.add_child(patch)
			far._patches[coord] = patch
	return far


## El chunk real ha llegado: su parche lejano se retira.
func hide_patch(coord: Vector2i) -> void:
	var patch: MeshInstance3D = _patches.get(coord)
	if patch != null:
		patch.visible = false


static func _build_patch(world_gen: WorldGen, coord: Vector2i) -> ArrayMesh:
	var side: int = PATCH_DIVISIONS + 1
	var step: float = TerrainChunk.CHUNK_SIZE / float(PATCH_DIVISIONS)
	var origin_x: float = float(coord.x) * TerrainChunk.CHUNK_SIZE
	var origin_z: float = float(coord.y) * TerrainChunk.CHUNK_SIZE
	var half: float = TerrainChunk.CHUNK_SIZE * 0.5
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	verts.resize(side * side)
	normals.resize(side * side)
	colors.resize(side * side)
	for iz: int in side:
		for ix: int in side:
			var idx: int = iz * side + ix
			var wx: float = origin_x + float(ix) * step
			var wz: float = origin_z + float(iz) * step
			verts[idx] = Vector3(
				float(ix) * step - half, world_gen.height(wx, wz), float(iz) * step - half
			)
			var hl: float = world_gen.height(wx - step, wz)
			var hr: float = world_gen.height(wx + step, wz)
			var hd: float = world_gen.height(wx, wz - step)
			var hu: float = world_gen.height(wx, wz + step)
			normals[idx] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
			# Bioma por vértice (G bosque, B colina, A clima): el mapa lejano
			# y la vista de águila muestran praderas, bosques, colinas, tundra
			# nevada y sabana — no un verde plano.
			colors[idx] = Color(
				0.0,
				world_gen.forest_weight(wx, wz),
				world_gen.highland_weight(wx, wz),
				world_gen.climate_tint(wx, wz)
			)
	for iz: int in side - 1:
		for ix: int in side - 1:
			var i00: int = iz * side + ix
			var i10: int = iz * side + ix + 1
			var i01: int = (iz + 1) * side + ix
			var i11: int = (iz + 1) * side + ix + 1
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
