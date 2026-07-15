class_name StateFarm
extends CitizenState
## Trabajar el huerto: ir a la parcela reclamada y plantar o cosechar.

const TIMEOUT: float = 45.0

var _arrived: bool = false
var _work_left: float = 0.0
var _timeout: float = 0.0


func state_name() -> StringName:
	return &"Farm"


func enter() -> void:
	_arrived = false
	_timeout = TIMEOUT
	var field: FarmField = citizen.task_target() as FarmField
	var task: TaskBoard.Task = citizen.current_task()
	if field == null or task == null:
		citizen.abandon_task(&"target_gone")
		citizen.state_machine.change(&"FindTask")
		return
	citizen.visual.mode = &"walk"
	var plot: int = int(task.payload.get("plot", 0))
	citizen.move_to(field.plot_position(plot))


func tick(dt: float) -> void:
	_timeout -= dt
	var field: FarmField = citizen.task_target() as FarmField
	var task: TaskBoard.Task = citizen.current_task()
	if field == null or task == null or _timeout <= 0.0:
		citizen.abandon_task(&"timeout")
		citizen.state_machine.change(&"FindTask")
		return
	var plot: int = int(task.payload.get("plot", 0))
	if not _arrived:
		var close: bool = citizen.global_position.distance_to(field.plot_position(plot)) < 1.4
		if not citizen.nav_finished() and not close:
			return
		citizen.stop_moving()
		citizen.face_towards(field.plot_position(plot))
		citizen.visual.mode = &"work"
		_arrived = true
		_work_left = FarmField.WORK_SECONDS
		return
	_work_left -= dt * citizen.effective_work_speed(&"farm")
	if _work_left > 0.0:
		return
	if task.kind == &"farm_plant":
		field.apply_plant(plot)
	else:
		field.apply_harvest(plot)
	TaskBoard.complete(task.id)
	citizen.current_task_id = -1
	citizen.state_machine.change(&"FindTask")


func exit() -> void:
	citizen.visual.mode = &"idle"


func on_stuck() -> void:
	citizen.state_machine.change(&"RecoverFromStuck")
