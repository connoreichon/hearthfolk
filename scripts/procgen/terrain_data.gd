class_name TerrainData
extends RefCounted
## Fachada de consulta del terreno (S1): delega en WorldGen (funciones
## puras a cualquier escala). La malla y la colisión viven en los chunks;
## la máscara de sendas es dispersa (celda de 1 m) y la escribirá el
## tráfico de la S3. API estable para todos los consumidores históricos.

var world_gen: WorldGen

## Sendas emergentes: celda Vector2i(1 m) → intensidad 0..1 (disperso).
var _path_cells: Dictionary = {}


func _init(gen: WorldGen = null) -> void:
	world_gen = gen


func get_height(x: float, z: float) -> float:
	return world_gen.height(x, z)


func get_normal(x: float, z: float) -> Vector3:
	var e: float = 0.5
	var hx: float = get_height(x + e, z) - get_height(x - e, z)
	var hz: float = get_height(x, z + e) - get_height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


func get_slope_deg(x: float, z: float) -> float:
	return rad_to_deg(acos(clampf(get_normal(x, z).y, -1.0, 1.0)))


func get_path_mask(x: float, z: float) -> float:
	return float(_path_cells.get(Vector2i(int(floor(x)), int(floor(z))), 0.0))


func set_path_mask(x: float, z: float, value: float) -> void:
	var cell: Vector2i = Vector2i(int(floor(x)), int(floor(z)))
	if value <= 0.0:
		_path_cells.erase(cell)
	else:
		_path_cells[cell] = clampf(value, 0.0, 1.0)


func is_inside(x: float, z: float, margin: float = 0.0) -> bool:
	return world_gen.is_inside(x, z, margin)
