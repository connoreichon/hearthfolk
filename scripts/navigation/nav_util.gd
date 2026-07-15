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


## Alcanzable Y a un paseo razonable. Un río rodeable por su nacimiento
## hace que is_reachable diga «sí» a caminatas de 400 m para cruzar 30 m:
## conectividad no es acceso. Aquí el camino real no puede superar
## max(slack, ratio × distancia recta).
static func is_practical(
	world: World3D,
	from: Vector3,
	to: Vector3,
	tolerance: float = 1.6,
	ratio: float = 3.0,
	slack: float = 60.0
) -> bool:
	var map: RID = world.navigation_map
	var path: PackedVector3Array = _best_path(map, from, to, tolerance)
	if path.is_empty():
		return false
	var length: float = 0.0
	for i: int in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	var straight: float = Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
	return length <= maxf(slack, straight * ratio)


## Primer camino que llega de verdad, con el mismo reintento en anillo
## que is_reachable (islas del snap del origen).
static func _best_path(
	map: RID, from: Vector3, to: Vector3, tolerance: float
) -> PackedVector3Array:
	var origins: Array[Vector3] = [from]
	for i: int in 6:
		var ang: float = TAU * float(i) / 6.0
		origins.append(from + Vector3(cos(ang), 0.0, sin(ang)) * 2.6)
	for origin: Vector3 in origins:
		var start: Vector3 = NavigationServer3D.map_get_closest_point(map, origin)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, to, true)
		if path.is_empty():
			continue
		var end: Vector3 = path[path.size() - 1]
		if Vector2(end.x, end.z).distance_to(Vector2(to.x, to.z)) <= tolerance:
			return path
	return PackedVector3Array()


static func _path_reaches(map: RID, from: Vector3, to: Vector3, tolerance: float) -> bool:
	var start: Vector3 = NavigationServer3D.map_get_closest_point(map, from)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, to, true)
	if path.is_empty():
		return false
	var end: Vector3 = path[path.size() - 1]
	var flat_end: Vector2 = Vector2(end.x, end.z)
	var flat_to: Vector2 = Vector2(to.x, to.z)
	return flat_end.distance_to(flat_to) <= tolerance
