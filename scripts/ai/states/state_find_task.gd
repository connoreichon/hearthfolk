class_name StateFindTask
extends CitizenState
## Evalúa prioridades (§7.3) y reclama la mejor tarea del TaskBoard.
## Regla de oro: nunca actuar sobre un objetivo sin reclamarlo.

## Presupuesto de distancia: en el mapa gigante, un trabajo a más de esto
## no es tuyo (los desvíos legales alrededor de un río podían convertir
## una tarea «cercana» en una expedición que caducaba a medio camino).
const MAX_TASK_DISTANCE: float = 45.0


func state_name() -> StringName:
	return &"FindTask"


func tick(_dt: float) -> void:
	# De noche no se reclaman tareas nuevas de tala/transporte/construcción
	if SimClock.is_night():
		citizen.state_machine.change(&"ReturnToSettlement")
		return
	# Sin herramientas se trabaja A PUÑOS, como los pioneros (orden del
	# dueño: «¿con qué se las han fabricado? ¡si acaban de llegar!»). Solo
	# cuando la VELADA enseñó a tallar Y hay madera en la despensa, el
	# colono se sienta junto al fuego a hacerse las suyas.
	if not citizen.data.has_tools:
		var camp: CampEntity = citizen.home_camp()
		if camp != null and camp.knows_tools() and GameState.get_resource(&"wood") >= 1:
			citizen.state_machine.change(&"Craft")
			return
	var task: TaskBoard.Task = TaskBoard.best_task_for(
		citizen.entity_id,
		citizen.global_position,
		[&"farm_harvest", &"haul", &"supply", &"chop", &"build", &"farm_plant", &"plant"],
		citizen.band_id,
		Professions.favored_kinds(citizen.data.profession)
	)
	if task == null:
		citizen.state_machine.change(&"Wander")
		return
	var target: Node3D = EntityRegistry.get_node_by_id(task.target_id) as Node3D
	if (
		target != null
		and citizen.global_position.distance_to(target.global_position) > MAX_TASK_DISTANCE
	):
		citizen.state_machine.change(&"Wander")
		return
	# Repoblar no tiene entidad destino: el punto viaja en el payload
	if task.kind == &"plant":
		var pos: Array = task.payload.get("pos", [])
		if pos.size() == 3:
			var spot: Vector3 = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
			if citizen.global_position.distance_to(spot) > MAX_TASK_DISTANCE:
				citizen.state_machine.change(&"Wander")
				return
	if not TaskBoard.claim(task.id, citizen.entity_id):
		citizen.state_machine.change(&"Wander")
		return
	citizen.current_task_id = task.id
	if task.kind == &"supply":
		citizen.state_machine.change(&"Supply")
	elif task.kind == &"farm_plant" or task.kind == &"farm_harvest":
		citizen.state_machine.change(&"Farm")
	elif task.kind == &"plant":
		citizen.state_machine.change(&"Plant")
	else:
		citizen.state_machine.change(&"MoveToResource")
