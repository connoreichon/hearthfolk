extends SceneTree
## Sonda del huerto (duck typing: script de entrada -s).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	var sim_clock: Node = root.get_node("/root/SimClock")
	var task_board: Node = root.get_node("/root/TaskBoard")
	game_state.call("setup_new_game", 2222)
	game_state.call("add_resource", &"food", 30)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	sim_clock.call("reset", 1, 0.3)
	sim_clock.call("set_speed", 4)
	for _f: int in 20:
		await process_frame
	var nav_region: Node3D = main.get_node("World/NavigationRegion3D") as Node3D
	var farm_script: GDScript = load("res://scripts/construction/farm_field.gd")
	var field: Node = farm_script.call("place", nav_region, Rect2(6.0, 6.0, 4.0, 4.0))
	await process_frame

	for step: int in 30:
		for _f: int in 120:
			await process_frame
		var states: Array[String] = []
		for node: Node in get_nodes_in_group(&"citizens"):
			states.append(str(node.get("state_machine").call("current_name")))
		var plots: Array = field.get("plots")
		var counts: Dictionary = {}
		for p: int in plots:
			counts[p] = int(counts.get(p, 0)) + 1
		print(
			(
				"t=%.0f | plots=%s | tareas=%s | comida=%s | items=%d | %s"
				% [
					sim_clock.get("elapsed_sim_seconds"),
					str(counts),
					str(task_board.call("stats")),
					str(game_state.call("get_resource", &"food")),
					get_nodes_in_group(&"resources").size(),
					" ".join(states)
				]
			)
		)
	quit(0)
