class_name StateFindTask
extends CitizenState
## Evalúa prioridades (§7.3) y reclama la mejor tarea del TaskBoard.
## Regla de oro: nunca actuar sobre un objetivo sin reclamarlo.


func state_name() -> StringName:
	return &"FindTask"


func tick(_dt: float) -> void:
	# De noche no se reclaman tareas nuevas de tala/transporte/construcción
	if SimClock.is_night():
		citizen.state_machine.change(&"ReturnToSettlement")
		return
	var task: TaskBoard.Task = TaskBoard.best_task_for(
		citizen.entity_id,
		citizen.global_position,
		[&"farm_harvest", &"haul", &"supply", &"chop", &"build", &"farm_plant"],
		citizen.band_id
	)
	if task == null:
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
	else:
		citizen.state_machine.change(&"MoveToResource")
