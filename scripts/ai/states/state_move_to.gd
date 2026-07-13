class_name StateMoveToResource
extends CitizenState
## Caminar hasta el objetivo de la tarea reclamada.

const TIMEOUT: float = 40.0
const STAND_OFF: float = 1.15
const REACH: float = 1.7

var _timeout: float = 0.0


func state_name() -> StringName:
	return &"MoveToResource"


func enter() -> void:
	_timeout = TIMEOUT
	var target: Node3D = citizen.task_target()
	if target == null:
		citizen.abandon_task(&"target_gone")
		citizen.state_machine.change(&"FindTask")
		return
	citizen.visual.mode = &"walk"
	citizen.move_to_near(target.global_position, STAND_OFF)


func tick(dt: float) -> void:
	_timeout -= dt
	var task: TaskBoard.Task = citizen.current_task()
	if task == null or citizen.task_target() == null:
		citizen.abandon_task(&"target_gone")
		citizen.state_machine.change(&"FindTask")
		return
	if _timeout <= 0.0:
		citizen.abandon_task(&"unreachable")
		citizen.state_machine.change(&"FindTask")
		return
	var target: Node3D = citizen.task_target()
	var close_enough: bool = (
		target != null and citizen.global_position.distance_to(target.global_position) < REACH
	)
	if citizen.nav_finished() or close_enough:
		citizen.stop_moving()
		match task.kind:
			&"chop":
				citizen.state_machine.change(&"Harvest")
			&"haul":
				citizen.state_machine.change(&"CarryResource")
			&"build":
				citizen.state_machine.change(&"Build")
			_:
				citizen.abandon_task(&"unknown_kind")
				citizen.state_machine.change(&"FindTask")


func on_stuck() -> void:
	citizen.state_machine.change(&"RecoverFromStuck")
