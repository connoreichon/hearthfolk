class_name StateEat
extends CitizenState
## Ir al carro, consumir 1 comida, 4 s de simulación, hambre → 100.

const EAT_SECONDS: float = 4.0

var _eating: bool = false
var _timer: float = 0.0
var _warned: bool = false


func state_name() -> StringName:
	return &"Eat"


func enter() -> void:
	_eating = false
	_timer = 0.0
	var storage: Node3D = citizen.find_storage()
	if storage == null:
		citizen.state_machine.change(&"Idle")
		return
	citizen.visual.mode = &"walk"
	var dir: Vector3 = (citizen.global_position - storage.global_position).normalized()
	citizen.move_to(storage.global_position + dir * 1.5)


func tick(dt: float) -> void:
	if not _eating:
		if not citizen.nav_finished():
			return
		citizen.stop_moving()
		if GameState.take_resource(&"food", 1):
			_eating = true
			_timer = EAT_SECONDS
			citizen.visual.mode = &"eat"
		else:
			if not _warned:
				_warned = true
				EventBus.toast.emit("No queda comida", &"warn")
			citizen.state_machine.change(&"Idle")
		return
	_timer -= dt
	if _timer <= 0.0:
		citizen.hunger = 100.0
		citizen.state_machine.change(&"Idle")


func exit() -> void:
	_warned = false
