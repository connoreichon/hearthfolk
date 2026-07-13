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
		citizen.entity_id, citizen.global_position, [&"haul", &"chop", &"build"]
	)
	if task == null:
		citizen.state_machine.change(&"Wander")
		return
	if not TaskBoard.claim(task.id, citizen.entity_id):
		citizen.state_machine.change(&"Wander")
		return
	citizen.current_task_id = task.id
	citizen.state_machine.change(&"MoveToResource")
