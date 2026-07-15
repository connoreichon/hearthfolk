class_name ChunkManager
extends Node3D
## Gestor de chunks del mapa gigante (S1): crea trozos de terreno alrededor
## de la actividad (campamentos, colonos, cámara) muestreando WorldGen.
## Los chunks ACTIVOS cuelgan del padre de navegación (sus colisiones
## entran en el bake); el resto existe solo como malla visual lejana.

var world_gen: WorldGen
## Padre de los chunks activos (la NavigationRegion3D del mundo).
var nav_parent: Node3D
## Terreno lejano: sus parches se ocultan cuando llega el chunk real.
var far_terrain: FarTerrain

var _chunks: Dictionary = {}


func coord_of(point: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(point.x / TerrainChunk.CHUNK_SIZE)), int(floor(point.z / TerrainChunk.CHUNK_SIZE))
	)


## Garantiza chunks vivos en un radio alrededor de un punto (en metros).
## Devuelve cuántos chunks nuevos ha creado.
func ensure_active_around(point: Vector3, radius: float = 96.0) -> int:
	var created: int = 0
	var span: int = int(ceil(radius / TerrainChunk.CHUNK_SIZE))
	var center: Vector2i = coord_of(point)
	for dz: int in range(-span, span + 1):
		for dx: int in range(-span, span + 1):
			var coord: Vector2i = center + Vector2i(dx, dz)
			if _chunks.has(coord):
				continue
			if not _coord_touches_map(coord):
				continue
			var chunk: TerrainChunk = TerrainChunk.create(world_gen, coord)
			_chunks[coord] = chunk
			nav_parent.add_child(chunk)
			chunk.populate(world_gen)
			if far_terrain != null:
				far_terrain.hide_patch(coord)
			created += 1
	return created


func chunk_at(coord: Vector2i) -> TerrainChunk:
	return _chunks.get(coord)


func active_count() -> int:
	return _chunks.size()


## ¿El chunk pisa el interior del mapa jugable?
func _coord_touches_map(coord: Vector2i) -> bool:
	var min_x: float = float(coord.x) * TerrainChunk.CHUNK_SIZE
	var min_z: float = float(coord.y) * TerrainChunk.CHUNK_SIZE
	var half: float = world_gen.map_half
	return (
		min_x < half
		and min_x + TerrainChunk.CHUNK_SIZE > -half
		and min_z < half
		and min_z + TerrainChunk.CHUNK_SIZE > -half
	)
