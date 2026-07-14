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
	citizen.move_to_near(dest.global_position, 4.0 if dest is ConstructionSite else 1.6)


func tick(dt: float) -> void:
	_timeout -= dt
	var dest: Node3D = _destination()
	if dest == null or _timeout <= 0.0:
		citizen.drop_carry(true)
		citizen.abandon_task(&"unreachable")
		citizen.state_machine.change(&"FindTask")
		return
	var arrive_dist: float = 4.8 if dest is ConstructionSite else 2.4
	var close: bool = citizen.global_position.distance_to(dest.global_position) < arrive_dist
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


## La madera del suelo va primero a la obra que la necesita (§7.3);
## si no hay obra con demanda, al carro.
func _destination() -> Node3D:
	var task: TaskBoard.Task = citizen.current_task()
	if task != null and task.payload.has("site_id"):
		return EntityRegistry.get_node_by_id(int(task.payload["site_id"])) as Node3D
	# Solo la madera interesa a las obras; la comida va siempre al carro
	if citizen.carrying_type != &"wood":
		return citizen.find_storage()
	var best_site: ConstructionSite = null
	var best_d: float = INF
	for node: Node in citizen.get_tree().get_nodes_in_group(&"construction_sites"):
		var site: ConstructionSite = node as ConstructionSite
		if site == null or site.completed:
			continue
		if site.delivered_total >= site.recipe.total_wood_cost():
			continue
		var d: float = site.global_position.distance_to(citizen.global_position)
		if d < best_d:
			best_d = d
			best_site = site
	if best_site != null:
		return best_site
	return citizen.find_storage()
