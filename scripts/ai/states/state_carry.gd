class_name StateCarryResource
extends CitizenState
## Recoger el haz reclamado: pequeña pausa agachado y a las manos.

const PICKUP_SECONDS: float = 0.5

var _timer: float = 0.0


func state_name() -> StringName:
	return &"CarryResource"


func enter() -> void:
	var item: ResourceItem = citizen.task_target() as ResourceItem
	if item == null:
		citizen.abandon_task(&"target_gone")
		citizen.state_machine.change(&"FindTask")
		return
	citizen.stop_moving()
	citizen.face_towards(item.global_position)
	citizen.visual.mode = &"work"
	_timer = PICKUP_SECONDS / citizen.effective_work_speed(&"haul")


func tick(dt: float) -> void:
	_timer -= dt
	if _timer > 0.0:
		return
	var item: ResourceItem = citizen.task_target() as ResourceItem
	if item == null:
		citizen.abandon_task(&"target_gone")
		citizen.state_machine.change(&"FindTask")
		return
	citizen.pick_up(item)
	citizen.state_machine.change(&"DeliverResource")
