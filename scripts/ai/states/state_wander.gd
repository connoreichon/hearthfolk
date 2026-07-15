class_name StateWander
extends CitizenState
## Paseo aleatorio cerca del asentamiento.

# Mínimo AMPLIO a propósito: pegados a la hoguera (agujero de navmesh +
# obstáculo RVO) muchos ociosos se agolpaban y se atascaban (soak S2). Un
# anillo de 6-16 m los reparte por el territorio sin salirse de él.
const RADIUS_MIN: float = 6.0
const RADIUS_MAX: float = 16.0

var _timeout: float = 0.0


func state_name() -> StringName:
	return &"Wander"


func enter() -> void:
	citizen.visual.mode = &"walk"
	_timeout = 25.0
	# El paseo es alrededor de SU hoguera (en el mapa gigante, un destino
	# absoluto mandaba a todo el mundo marchando hacia el centro del mapa).
	var center: Vector3 = citizen.global_position
	var camp: CampEntity = citizen.home_camp()
	if camp != null:
		center = camp.global_position
	var target: Vector3 = _forage_spot(center)
	if target == Vector3.INF:
		var ang: float = citizen.local_rng.randf() * TAU
		var radius: float = citizen.local_rng.randf_range(RADIUS_MIN, RADIUS_MAX)
		target = center + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
	if GameState.terrain != null:
		target.y = GameState.terrain.get_height(target.x, target.z)
	citizen.move_to(target)


## Paseo FORRAJERO (orden del dueño): la mayoría de las veces el ocio es
## curiosear un recurso del territorio — un árbol, un arbusto — no vagar.
func _forage_spot(center: Vector3) -> Vector3:
	if citizen.local_rng.randf() > 0.65:
		return Vector3.INF
	var spots: Array[Vector3] = []
	for node: Node in citizen.get_tree().get_nodes_in_group(&"trees"):
		var p: Vector3 = (node as Node3D).global_position
		if p.distance_to(center) < 20.0:
			spots.append(p)
			if spots.size() >= 12:
				break
	if spots.is_empty():
		return Vector3.INF
	var pick: Vector3 = spots[citizen.local_rng.randi_range(0, spots.size() - 1)]
	var away: float = citizen.local_rng.randf() * TAU
	return pick + Vector3(cos(away) * 1.6, 0.0, sin(away) * 1.6)


func tick(dt: float) -> void:
	_timeout -= dt
	if citizen.nav_finished() or _timeout <= 0.0:
		citizen.state_machine.change(&"Idle")
