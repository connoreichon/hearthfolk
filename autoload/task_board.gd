extends Node
## Tareas y reservas. claim() es la única puerta de entrada a un objetivo.
## Un habitante nunca actúa sobre algo que no ha reclamado aquí.

const CLAIM_TTL_DEFAULT: float = 45.0
const FAILURE_LIMIT: int = 3
const FAILURE_COOLDOWN: float = 20.0

var _tasks: Dictionary = {}
var _next_task_id: int = 1
var _failed_count: int = 0


class Task:
	var id: int = 0
	var kind: StringName = &""
	var target_id: int = 0
	var payload: Dictionary = {}
	var priority: int = 5
	var claimed_by: int = -1
	var claimed_at: float = -1.0
	var ttl: float = 45.0
	var failures: int = 0
	var blacklist: Array[int] = []
	var cooldown_until: float = -1.0


func _ready() -> void:
	SimClock.sim_tick.connect(_on_sim_tick)


func publish(kind: StringName, target_id: int, payload: Dictionary = {}, priority: int = 5) -> int:
	var task: Task = Task.new()
	task.id = _next_task_id
	_next_task_id += 1
	task.kind = kind
	task.target_id = target_id
	task.payload = payload
	task.priority = priority
	task.ttl = CLAIM_TTL_DEFAULT
	_tasks[task.id] = task
	EventBus.task_published.emit(task.id, kind)
	return task.id


## Reclamación atómica: false si ya está reclamada, en blacklist o en cooldown.
func claim(task_id: int, citizen_id: int) -> bool:
	var task: Task = _tasks.get(task_id)
	if task == null:
		return false
	if task.claimed_by != -1:
		return false
	if citizen_id in task.blacklist:
		return false
	if task.cooldown_until > SimClock.elapsed_sim_seconds:
		return false
	task.claimed_by = citizen_id
	task.claimed_at = SimClock.elapsed_sim_seconds
	EventBus.task_claimed.emit(task_id, citizen_id)
	return true


func release(task_id: int, citizen_id: int, reason: StringName) -> void:
	var task: Task = _tasks.get(task_id)
	if task == null or task.claimed_by != citizen_id:
		return
	task.claimed_by = -1
	task.claimed_at = -1.0
	if reason != &"yield":
		task.failures += 1
		_failed_count += 1
		if task.failures >= FAILURE_LIMIT:
			if citizen_id not in task.blacklist:
				task.blacklist.append(citizen_id)
			task.cooldown_until = SimClock.elapsed_sim_seconds + FAILURE_COOLDOWN
			task.failures = 0
	EventBus.task_released.emit(task_id, reason)


func complete(task_id: int) -> void:
	if not _tasks.has(task_id):
		return
	_tasks.erase(task_id)
	EventBus.task_completed.emit(task_id)


## Cancela sin considerarse fallo (p. ej. el objetivo ya no existe).
func cancel(task_id: int, reason: StringName = &"cancelled") -> void:
	if not _tasks.has(task_id):
		return
	_tasks.erase(task_id)
	EventBus.task_released.emit(task_id, reason)


## Cancela de golpe todas las tareas de un objetivo (demolición).
func cancel_for_target(target_id: int, reason: StringName = &"cancelled") -> void:
	for task_id: int in _tasks.keys():
		if (_tasks[task_id] as Task).target_id == target_id:
			cancel(task_id, reason)


func get_task(task_id: int) -> Task:
	return _tasks.get(task_id)


func claimed_task_of(citizen_id: int) -> Task:
	for task: Task in _tasks.values():
		if task.claimed_by == citizen_id:
			return task
	return null


func first_task_for_target(target_id: int, kind: StringName = &"") -> Task:
	for task: Task in _tasks.values():
		if task.target_id != target_id:
			continue
		if kind != &"" and task.kind != kind:
			continue
		return task
	return null


## Mejor tarea libre para un habitante: filtra blacklist, cooldown y BANDA
## (las tareas etiquetadas con "band" son de esa aldea — nadie cruza medio
## mapa a trabajar para otros), ordena por prioridad (0 = máxima) y
## después por distancia.
func best_task_for(
	citizen_id: int, from_position: Vector3, kinds: Array[StringName] = [], band: int = -1
) -> Task:
	var best: Task = null
	var best_score: float = INF
	for task: Task in _tasks.values():
		if task.claimed_by != -1:
			continue
		if citizen_id in task.blacklist:
			continue
		if task.cooldown_until > SimClock.elapsed_sim_seconds:
			continue
		if not kinds.is_empty() and task.kind not in kinds:
			continue
		if band >= 0 and task.payload.has("band") and int(task.payload["band"]) != band:
			continue
		var dist: float = 0.0
		var target: Node = EntityRegistry.get_node_by_id(task.target_id)
		if target is Node3D:
			dist = from_position.distance_to((target as Node3D).global_position)
		var score: float = float(task.priority) * 1000.0 + dist
		if score < best_score:
			best_score = score
			best = task
	return best


func stats() -> Dictionary:
	var free: int = 0
	var claimed: int = 0
	for task: Task in _tasks.values():
		if task.claimed_by == -1:
			free += 1
		else:
			claimed += 1
	return {"free": free, "claimed": claimed, "failed_total": _failed_count}


func clear() -> void:
	_tasks.clear()
	_next_task_id = 1
	_failed_count = 0


## Corre cada sim_tick: expira reclamaciones por TTL y purga tareas
## cuyo objetivo ya no existe en EntityRegistry.
func _on_sim_tick(_delta: float) -> void:
	var to_cancel: Array[int] = []
	for task: Task in _tasks.values():
		if task.claimed_by != -1 and SimClock.elapsed_sim_seconds - task.claimed_at > task.ttl:
			release(task.id, task.claimed_by, &"ttl")
		if task.target_id > 0 and EntityRegistry.get_node_by_id(task.target_id) == null:
			to_cancel.append(task.id)
	for task_id: int in to_cancel:
		cancel(task_id, &"target_gone")
