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
	# move_to_near pega el destino al navmesh: el carro talla un agujero
	# y un punto a 1.5 m del centro puede caer dentro (bug del soak 002)
	citizen.move_to_near(storage.global_position, 2.0)


func tick(dt: float) -> void:
	if not _eating:
		var storage: Node3D = citizen.find_storage()
		var close: bool = (
			storage != null and citizen.global_position.distance_to(storage.global_position) < 3.0
		)
		if not citizen.nav_finished() and not close:
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
