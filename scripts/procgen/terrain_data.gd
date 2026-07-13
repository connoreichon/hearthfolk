class_name TerrainData
extends RefCounted
## Heightfield del mapa: consultas de altura, normal y pendiente.
## Mundo centrado en (0,0,0), 120×120 m, resolución 1 m.

const SIZE: float = 120.0
const RESOLUTION: int = 120

var heights: PackedFloat32Array = PackedFloat32Array()
var path_mask: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	var count: int = (RESOLUTION + 1) * (RESOLUTION + 1)
	heights.resize(count)
	path_mask.resize(count)


func vertex_side() -> int:
	return RESOLUTION + 1


func index_of(ix: int, iz: int) -> int:
	return iz * (RESOLUTION + 1) + ix


func height_at(ix: int, iz: int) -> float:
	ix = clampi(ix, 0, RESOLUTION)
	iz = clampi(iz, 0, RESOLUTION)
	return heights[index_of(ix, iz)]


## Altura bilineal en coordenadas de mundo.
func get_height(x: float, z: float) -> float:
	var fx: float = clampf(x + SIZE * 0.5, 0.0, SIZE - 0.001)
	var fz: float = clampf(z + SIZE * 0.5, 0.0, SIZE - 0.001)
	var ix: int = int(fx)
	var iz: int = int(fz)
	var tx: float = fx - float(ix)
	var tz: float = fz - float(iz)
	var h00: float = height_at(ix, iz)
	var h10: float = height_at(ix + 1, iz)
	var h01: float = height_at(ix, iz + 1)
	var h11: float = height_at(ix + 1, iz + 1)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func get_normal(x: float, z: float) -> Vector3:
	var e: float = 0.5
	var hx: float = get_height(x + e, z) - get_height(x - e, z)
	var hz: float = get_height(x, z + e) - get_height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


func get_slope_deg(x: float, z: float) -> float:
	return rad_to_deg(acos(clampf(get_normal(x, z).y, -1.0, 1.0)))


func get_path_mask(x: float, z: float) -> float:
	var fx: float = clampf(x + SIZE * 0.5, 0.0, SIZE - 0.001)
	var fz: float = clampf(z + SIZE * 0.5, 0.0, SIZE - 0.001)
	return path_mask[index_of(int(fx), int(fz))]


func is_inside(x: float, z: float, margin: float = 0.0) -> bool:
	var half: float = SIZE * 0.5 - margin
	return absf(x) <= half and absf(z) <= half
