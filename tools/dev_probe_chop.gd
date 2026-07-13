extends SceneTree
## Sonda de tala. Sin referencias estáticas a clases del juego: el script de
## entrada -s compila antes que los autoloads y arrastraría su compilación.

var _stuck_events: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	var sim_clock: Node = root.get_node("/root/SimClock")
	var task_board: Node = root.get_node("/root/TaskBoard")
	var registry: Node = root.get_node("/root/EntityRegistry")
	var event_bus: Node = root.get_node("/root/EventBus")
	game_state.call("setup_new_game", 2222)
	game_state.call("add_resource", &"food", 12)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	sim_clock.call("reset", 1, 0.3)
	sim_clock.call("set_speed", 4)
	event_bus.connect("citizen_stuck", func(_id: int, _pos: Vector3) -> void: _stuck_events += 1)
	for _f: int in 20:
		await process_frame

	var best: Node3D = null
	var best_d: float = INF
	for node: Node in get_nodes_in_group(&"trees"):
		if not bool(node.call("choppable")):
			continue
		var d: float = (node as Node3D).global_position.length()
		if d < best_d:
			best_d = d
			best = node
	print("arbol id=%d pos=%s dist=%.1f" % [best.get("entity_id"), best.global_position, best_d])
	best.call("set_marked", true)
	task_board.call("publish", &"chop", best.get("entity_id"), {}, 5)

	for _step: int in 40:
		for _f: int in 60:
			await process_frame
		var lines: Array[String] = []
		for node: Node in get_nodes_in_group(&"citizens"):
			var d_tree: float = -1.0
			if is_instance_valid(best):
				d_tree = (node as Node3D).global_position.distance_to(best.global_position)
			var sm: RefCounted = node.get("state_machine")
			lines.append(
				(
					"%s:%s task=%d d=%.1f"
					% [
						node.get("data").get("display_name"),
						sm.call("current_name"),
						node.get("current_task_id"),
						d_tree
					]
				)
			)
		var hp_txt: String = str(best.get("hp")) if is_instance_valid(best) else "GONE"
		print(
			(
				"t=%.0f hp=%s stuck=%d | %s"
				% [sim_clock.get("elapsed_sim_seconds"), hp_txt, _stuck_events, " | ".join(lines)]
			)
		)
		var tobin: Node = null
		for node: Node in get_nodes_in_group(&"citizens"):
			if node.get("data").get("display_name") == "Tobin":
				tobin = node
		if tobin != null:
			var agent: NavigationAgent3D = tobin.get("nav_agent")
			var path: PackedVector3Array = agent.get_current_navigation_path()
			print(
				(
					"  tobin pos=%s navfin=%s dist_t=%.2f vel=%s path_len=%d idx=%d wp=%s"
					% [
						(tobin as Node3D).global_position,
						agent.is_navigation_finished(),
						agent.distance_to_target(),
						tobin.get("velocity"),
						path.size(),
						agent.get_current_navigation_path_index(),
						(
							str(path[agent.get_current_navigation_path_index()])
							if path.size() > 0
							else "-"
						)
					]
				)
			)
		if not is_instance_valid(best):
			break
	var wood: int = 0
	for node: Node in get_nodes_in_group(&"resources"):
		wood += int(node.get("amount"))
	var stumps: Array = registry.call("all_of_kind", &"stump")
	print("madera final=%d tocones=%d" % [wood, stumps.size()])
	quit(0)
