class_name StateEat
extends CitizenState
## Ir al carro, consumir 1 comida, 4 s de simulación, hambre → 100.

const EAT_SECONDS: float = 4.0

var _eating: bool = false
var _timer: float = 0.0
var _approach: float = 0.0
var _warned: bool = false


func state_name() -> StringName:
	return &"Eat"


func enter() -> void:
	_eating = false
	_timer = 0.0
	_approach = 0.0
	var storage: Node3D = citizen.find_storage()
	if storage == null:
		citizen.state_machine.change(&"Idle")
		return
	citizen.visual.mode = &"walk"
	# move_to_near pega el destino al navmesh: el carro talla un agujero
	# y un punto a 1.5 m del centro puede caer dentro (bug del soak 002)
	citizen.move_to_near(storage.global_position, 2.4)


func tick(dt: float) -> void:
	if not _eating:
		_approach += dt
		# CARRO INALCANZABLE (isla tras un brazo de río, o prendido contra un
		# labio del terreno): no perseguir el imposible — recuperar hacia el
		# asentamiento (rescate a la hoguera o salto hacia casa, según el
		# caso). Cazado en el soak S2: colonos empujando el terreno a 13 m de
		# su fuego sin poder volver a comer. Esto solo corre para los que
		# comen, no toca a la cuadrilla del huerto.
		if _approach > 2.0 and not citizen.nav_agent.is_target_reachable():
			if citizen.recover_home():
				return
		var storage: Node3D = citizen.find_storage()
		var close: bool = (
			storage != null and citizen.global_position.distance_to(storage.global_position) < 3.4
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


## Al atascarse yendo a comer: si el colono está VARADO (un brazo de río lo
## dejó en una isla lejos de su hoguera, sin poder volver al carro), se le
## rescata a su asentamiento; si es un atasco local, se reintenta la ruta.
func on_stuck() -> void:
	if citizen.is_stranded_from_home() and citizen.rescue_home():
		return
	enter()


func exit() -> void:
	_warned = false
