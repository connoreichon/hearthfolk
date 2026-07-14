class_name NavUtil
## Utilidades de navegación: comprobación de alcanzabilidad (§16).


static func is_reachable(
	world: World3D, from: Vector3, to: Vector3, tolerance: float = 1.6
) -> bool:
	var map: RID = world.navigation_map
	if _path_reaches(map, from, to, tolerance):
		return true
	# El snap del origen puede caer en una ISLA del navmesh (p. ej. la tapa
	# horneada del collider de la fogata queda más cerca de su centro que el
	# anillo del suelo) y el camino muere sin salir de ella. Reintentar desde
	# un anillo alrededor del origen, fuera del agujero del collider.
	for i: int in 6:
		var ang: float = TAU * float(i) / 6.0
		var probe: Vector3 = from + Vector3(cos(ang), 0.0, sin(ang)) * 2.6
		if _path_reaches(map, probe, to, tolerance):
			return true
	return false


static func _path_reaches(map: RID, from: Vector3, to: Vector3, tolerance: float) -> bool:
	var start: Vector3 = NavigationServer3D.map_get_closest_point(map, from)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, to, true)
	if path.is_empty():
		return false
	var end: Vector3 = path[path.size() - 1]
	var flat_end: Vector2 = Vector2(end.x, end.z)
	var flat_to: Vector2 = Vector2(to.x, to.z)
	return flat_end.distance_to(flat_to) <= tolerance
