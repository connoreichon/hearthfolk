extends SceneTree
## Sonda mínima de movimiento: desplazamiento de habitantes en 600 frames.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	var sim_clock: Node = root.get_node("/root/SimClock")
	game_state.call("setup_new_game", 2222)
	game_state.call("add_resource", &"food", 12)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	sim_clock.call("reset", 1, 0.3)
	sim_clock.call("set_speed", 4)
	for _f: int in 30:
		await process_frame
	var citizens: Array[Node] = get_nodes_in_group(&"citizens")
	var starts: Array[Vector3] = []
	for node: Node in citizens:
		starts.append((node as Node3D).global_position)
	for _f: int in 600:
		await process_frame
	for i: int in citizens.size():
		var citizen: Node3D = citizens[i] as Node3D
		var agent: NavigationAgent3D = citizen.get("nav_agent")
		var path: PackedVector3Array = agent.get_current_navigation_path()
		print(
			(
				"c%d desplazamiento=%.2f pos=%s navfin=%s path=%d idx=%d"
				% [
					i,
					citizen.global_position.distance_to(starts[i]),
					citizen.global_position,
					agent.is_navigation_finished(),
					path.size(),
					agent.get_current_navigation_path_index()
				]
			)
		)
		if path.size() > 0:
			var idx: int = agent.get_current_navigation_path_index()
			var wp: Vector3 = path[mini(idx, path.size() - 1)]
			print(
				(
					"   wp=%s  dy=%.2f  dxz=%.2f"
					% [
						wp,
						absf(wp.y - citizen.global_position.y),
						(
							Vector2(
								wp.x - citizen.global_position.x, wp.z - citizen.global_position.z
							)
							. length()
						)
					]
				)
			)
	quit(0)
