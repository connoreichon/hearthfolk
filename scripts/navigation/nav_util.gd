class_name NavUtil
## Utilidades de navegación: comprobación de alcanzabilidad (§16).


static func is_reachable(
	world: World3D, from: Vector3, to: Vector3, tolerance: float = 1.6
) -> bool:
	var map: RID = world.navigation_map
	var start: Vector3 = NavigationServer3D.map_get_closest_point(map, from)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, to, true)
	if path.is_empty():
		return false
	var end: Vector3 = path[path.size() - 1]
	var flat_end: Vector2 = Vector2(end.x, end.z)
	var flat_to: Vector2 = Vector2(to.x, to.z)
	return flat_end.distance_to(flat_to) <= tolerance
