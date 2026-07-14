class_name StateBuild
extends CitizenState
## Martillear en la obra reclamada hasta que la fase avance o falte material.


func state_name() -> StringName:
	return &"Build"


func enter() -> void:
	var site: ConstructionSite = citizen.task_target() as ConstructionSite
	if site == null:
		citizen.abandon_task(&"target_gone")
		citizen.state_machine.change(&"FindTask")
		return
	citizen.stop_moving()
	citizen.face_towards(site.global_position)
	citizen.visual.mode = &"work"


func tick(dt: float) -> void:
	var task: TaskBoard.Task = citizen.current_task()
	var site: ConstructionSite = citizen.task_target() as ConstructionSite
	if task == null or site == null:
		citizen.abandon_task(&"target_gone")
		citizen.state_machine.change(&"FindTask")
		return
	if site.completed:
		TaskBoard.complete(task.id)
		citizen.current_task_id = -1
		citizen.state_machine.change(&"FindTask")
		return
	if not site.can_work_now():
		citizen.abandon_task(&"yield")
		citizen.state_machine.change(&"FindTask")
		return
	site.apply_work(dt * citizen.effective_work_speed() * ConstructionSite.BUILD_RATE)


func exit() -> void:
	citizen.visual.mode = &"idle"
