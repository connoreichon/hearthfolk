class_name StateSupply
extends CitizenState
## Llevar madera del almacén a una obra: ir al carro, coger, entregar.

const TIMEOUT: float = 60.0

var _fetched: bool = false
var _timeout: float = 0.0


func state_name() -> StringName:
	return &"Supply"


func enter() -> void:
	_fetched = false
	_timeout = TIMEOUT
	var storage: Node3D = citizen.find_storage()
	var task: TaskBoard.Task = citizen.current_task()
	if storage == null or task == null:
		citizen.abandon_task(&"no_destination")
		citizen.state_machine.change(&"FindTask")
		return
	citizen.visual.mode = &"walk"
	citizen.move_to_near(storage.global_position, 1.6)


func tick(dt: float) -> void:
	_timeout -= dt
	var task: TaskBoard.Task = citizen.current_task()
	if task == null or _timeout <= 0.0:
		citizen.drop_carry(true)
		citizen.abandon_task(&"timeout")
		citizen.state_machine.change(&"FindTask")
		return
	var site: ConstructionSite = citizen.task_target() as ConstructionSite
	if site == null:
		citizen.drop_carry(true)
		citizen.abandon_task(&"target_gone")
		citizen.state_machine.change(&"FindTask")
		return
	if not _fetched:
		if not citizen.nav_finished():
			return
		citizen.stop_moving()
		var amount: int = int(task.payload.get("amount", 2))
		if not GameState.take_resource(&"wood", amount):
			citizen.abandon_task(&"no_material")
			citizen.state_machine.change(&"FindTask")
			return
		citizen.load_carry(&"wood", amount)
		_fetched = true
		citizen.visual.mode = &"carry"
		citizen.move_to_near(site.global_position, 4.0)
		return
	var close: bool = citizen.global_position.distance_to(site.global_position) < 4.8
	if citizen.nav_finished() or close:
		citizen.stop_moving()
		citizen.deliver_carry(site)
		TaskBoard.complete(task.id)
		citizen.current_task_id = -1
		citizen.state_machine.change(&"FindTask")


func on_stuck() -> void:
	citizen.state_machine.change(&"RecoverFromStuck")
