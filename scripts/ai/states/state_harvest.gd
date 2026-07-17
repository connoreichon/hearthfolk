class_name StateHarvest
extends CitizenState
## Talar el árbol reclamado: un golpe cada ~1.2 s de simulación.

const HIT_INTERVAL: float = 1.2

var _hit_timer: float = 0.0


func state_name() -> StringName:
	return &"Harvest"


func enter() -> void:
	var target: Node3D = citizen.task_target()
	if target == null:
		citizen.abandon_task(&"target_gone")
		citizen.state_machine.change(&"FindTask")
		return
	citizen.stop_moving()
	citizen.visual.mode = &"work"
	citizen.face_towards(target.global_position)
	_hit_timer = HIT_INTERVAL / citizen.effective_work_speed(&"chop")
	# El hacha SALE de la espalda y el gesto marca el compás del golpe real
	citizen.visual.set_work_style(&"chop", _hit_timer)
	citizen.visual.equip_tool()


func tick(dt: float) -> void:
	var task: TaskBoard.Task = citizen.current_task()
	var tree: TreeEntity = citizen.task_target() as TreeEntity
	if task == null or tree == null or tree.felled:
		citizen.abandon_task(&"target_gone")
		citizen.state_machine.change(&"FindTask")
		return
	_hit_timer -= dt
	if _hit_timer > 0.0:
		return
	_hit_timer = HIT_INTERVAL / citizen.effective_work_speed(&"chop")
	if tree.take_hit():
		TaskBoard.complete(task.id)
		citizen.current_task_id = -1
		citizen.state_machine.change(&"FindTask")


func exit() -> void:
	citizen.visual.mode = &"idle"
	citizen.visual.stow_tool()
