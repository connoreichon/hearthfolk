class_name StateMachine
extends RefCounted
## FSM explícita: estados con enter/tick/exit, sin match gigante.

var citizen: Citizen
var current: CitizenState
var states: Dictionary = {}


func _init(owner_citizen: Citizen) -> void:
	citizen = owner_citizen


func add(state: CitizenState) -> void:
	state.citizen = citizen
	states[state.state_name()] = state


func change(new_state: StringName) -> void:
	if current != null and current.state_name() == new_state:
		return
	if current != null:
		current.exit()
	current = states.get(new_state)
	if current == null:
		push_error("StateMachine: estado desconocido %s" % new_state)
		return
	current.enter()
	EventBus.citizen_state_changed.emit(citizen.entity_id, new_state)


func tick(dt: float) -> void:
	if current != null:
		current.tick(dt)


func current_name() -> StringName:
	return current.state_name() if current != null else &""


func on_stuck() -> void:
	if current != null:
		current.on_stuck()
