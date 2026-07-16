class_name StateRecoverFromStuck
extends CitizenState
## Recuperación de bloqueo (§7.4): reintento → apartarse → teleport suave.

var _attempt: int = 0
var _wait: float = 0.0


func state_name() -> StringName:
	return &"RecoverFromStuck"


func enter() -> void:
	_attempt += 1
	_wait = 0.5
	var map: RID = citizen.get_world_3d().navigation_map
	# Mapa sin su primera sincronización: no hay recuperación que hacer aún
	if not NavUtil.map_ready(map):
		return
	match _attempt:
		1:
			# (a) reintentar la ruta actual
			var target: Node3D = citizen.task_target()
			if target != null:
				citizen.move_to(target.global_position)
			else:
				_side_step(map)
		2:
			# (b) apartarse a un punto navegable a 2–4 m
			_side_step(map)
		_:
			# (c) teleport suave A SU ISLA: el «punto navegable más cercano»
			# desde una orilla podía ser LA OTRA ORILLA y exiliaba al colono
			# al otro lado del río. El final del camino DESDE SU HOGUERA
			# hasta aquí siempre pisa la isla del campamento.
			var camp: CampEntity = citizen.home_camp()
			var anchor: Vector3 = camp.global_position if camp != null else citizen.global_position
			var home_path: PackedVector3Array = NavigationServer3D.map_get_path(
				map, anchor, citizen.global_position, true
			)
			var safe: Vector3 = anchor + Vector3(2.0, 0.05, 2.0)
			if not home_path.is_empty():
				safe = home_path[home_path.size() - 1]
			citizen.fade_teleport(safe)
			citizen.abandon_task(&"stuck")
			_attempt = 0


func tick(dt: float) -> void:
	_wait -= dt
	if _wait > 0.0:
		return
	# Reanudar la tarea EN SU ESTADO (el enrutado ciego a MoveToResource
	# tiraba las tareas de suministro y huerto como «desconocidas» y el
	# suministrador entraba en bucle: atasco → estado equivocado → abandono).
	var task: TaskBoard.Task = citizen.current_task()
	if task == null:
		citizen.state_machine.change(&"FindTask")
	elif task.kind == &"supply":
		citizen.state_machine.change(&"Supply")
	elif task.kind == &"farm_plant" or task.kind == &"farm_harvest":
		citizen.state_machine.change(&"Farm")
	else:
		citizen.state_machine.change(&"MoveToResource")


func on_stuck() -> void:
	enter()


func _side_step(map: RID) -> void:
	var ang: float = citizen.local_rng.randf() * TAU
	var radius: float = citizen.local_rng.randf_range(2.0, 4.0)
	var side: Vector3 = citizen.global_position + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
	if not NavUtil.map_ready(map):
		citizen.move_to(side)
		return
	# Final del camino real: nunca apuntar a la isla de enfrente
	var path: PackedVector3Array = NavigationServer3D.map_get_path(
		map, citizen.global_position, side, true
	)
	if path.is_empty():
		citizen.move_to(NavigationServer3D.map_get_closest_point(map, side))
	else:
		citizen.move_to(path[path.size() - 1])
