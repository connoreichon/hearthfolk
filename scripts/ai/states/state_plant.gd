class_name StatePlant
extends CitizenState
## Repoblar (Build 004, oficio nuevo): ir al claro señalado, arrodillarse
## con la pala y PLANTAR un brote. El bosque talado vuelve a crecer.

const WORK_SECONDS: float = 3.2
const TIMEOUT: float = 60.0

var _arrived: bool = false
var _work_left: float = 0.0
var _timeout: float = 0.0
var _spot: Vector3


func state_name() -> StringName:
	return &"Plant"


func enter() -> void:
	var task: TaskBoard.Task = citizen.current_task()
	if task == null:
		citizen.state_machine.change(&"FindTask")
		return
	var pos: Array = task.payload.get("pos", [])
	if pos.size() != 3:
		citizen.abandon_task(&"target_gone")
		citizen.state_machine.change(&"FindTask")
		return
	_spot = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	_arrived = false
	_timeout = TIMEOUT
	citizen.visual.mode = &"walk"
	citizen.move_to(_spot)


func tick(dt: float) -> void:
	_timeout -= dt
	var task: TaskBoard.Task = citizen.current_task()
	if task == null or _timeout <= 0.0:
		citizen.abandon_task(&"timeout")
		citizen.state_machine.change(&"FindTask")
		return
	if not _arrived:
		if not citizen.nav_finished() and citizen.global_position.distance_to(_spot) > 1.6:
			return
		citizen.stop_moving()
		citizen.face_towards(_spot)
		citizen.visual.mode = &"work"
		# La pala sale de la espalda: siembra en cuclillas, sin prisa
		citizen.visual.set_work_style(&"plant", 1.1)
		citizen.visual.equip_tool()
		_arrived = true
		_work_left = WORK_SECONDS
		return
	_work_left -= dt * citizen.effective_work_speed(&"plant")
	if _work_left > 0.0:
		return
	_sprout()
	TaskBoard.complete(task.id)
	citizen.current_task_id = -1
	citizen.state_machine.change(&"FindTask")


func exit() -> void:
	citizen.visual.mode = &"idle"
	citizen.visual.stow_tool()


func on_stuck() -> void:
	citizen.state_machine.change(&"RecoverFromStuck")


## Nace el brote: árbol JOVEN con ID dinámico. Persiste en el guardado —
## el load ya recrea los árboles no deterministas desde su save_data.
func _sprout() -> void:
	var tree: TreeEntity = TreeEntity.create(GameState.rng.randi(), true)
	var world: Node = citizen.get_tree().get_first_node_in_group(&"world")
	if world == null:
		return
	var nav_region: Node3D = world.get_node_or_null("NavigationRegion3D") as Node3D
	if nav_region == null:
		tree.free()
		return
	tree.entity_id = EntityRegistry.register(tree, &"tree")
	nav_region.add_child(tree)
	tree.global_position = _spot
	tree.rotation.y = GameState.rng.randf() * TAU
	FloatingText.spawn(tree, _spot + Vector3(0.0, 1.2, 0.0), "¡Un brote!", Color("#94B86A"))
