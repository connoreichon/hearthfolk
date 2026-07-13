class_name StateDeliverResource
extends CitizenState
## Llevar la carga al destino (carro; obras en P6) y depositarla.

const TIMEOUT: float = 50.0

var _timeout: float = 0.0


func state_name() -> StringName:
	return &"DeliverResource"


func enter() -> void:
	_timeout = TIMEOUT
	var dest: Node3D = _destination()
	if dest == null:
		citizen.drop_carry(true)
		citizen.abandon_task(&"no_destination")
		citizen.state_machine.change(&"FindTask")
		return
	citizen.visual.mode = &"carry"
	citizen.move_to_near(dest.global_position, 1.6)


func tick(dt: float) -> void:
	_timeout -= dt
	var dest: Node3D = _destination()
	if dest == null or _timeout <= 0.0:
		citizen.drop_carry(true)
		citizen.abandon_task(&"unreachable")
		citizen.state_machine.change(&"FindTask")
		return
	var close: bool = citizen.global_position.distance_to(dest.global_position) < 2.4
	if citizen.nav_finished() or close:
		citizen.stop_moving()
		citizen.deliver_carry(dest)
		var task: TaskBoard.Task = citizen.current_task()
		if task != null:
			TaskBoard.complete(task.id)
		citizen.current_task_id = -1
		citizen.state_machine.change(&"FindTask")


func on_stuck() -> void:
	citizen.state_machine.change(&"RecoverFromStuck")


## P5: siempre el carro. En P6 las obras que esperan material tienen prioridad.
func _destination() -> Node3D:
	var task: TaskBoard.Task = citizen.current_task()
	if task != null and task.payload.has("site_id"):
		return EntityRegistry.get_node_by_id(int(task.payload["site_id"])) as Node3D
	return citizen.find_storage()
