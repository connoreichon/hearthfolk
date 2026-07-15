extends SceneTree
## Sonda: por qué la aldea (semilla 2222) no encuentra parcela de huerto.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	game_state.call("setup_new_game", 2222)
	game_state.call("add_resource", &"wood", 24)
	game_state.call("add_resource", &"food", 2)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 20:
		await process_frame
	var camp: Node3D = get_nodes_in_group(&"camps")[0] as Node3D
	var tools: Node = get_tree_nodes_first(&"tool_manager")
	print("PROBE camp=%s tools=%s" % [camp.global_position, str(tools != null)])
	var world_3d: World3D = (main as Node3D).get_world_3d()
	var reasons: Dictionary = {}
	var valid_found: int = 0
	for radius: float in [9.0, 12.0, 15.0, 18.0, 21.0]:
		for step: int in 10:
			var ang: float = TAU * float(step) / 10.0 + 0.35
			var cx: float = camp.global_position.x + cos(ang) * radius
			var cz: float = camp.global_position.z + sin(ang) * radius
			var rect: Rect2 = Rect2(cx - 3.0, cz - 3.0, 6.0, 6.0)
			var verdict: Dictionary = tools.call("validate_zone", rect, world_3d, &"farm")
			if bool(verdict["valid"]):
				valid_found += 1
				if valid_found == 1:
					print("PROBE primera válida: r=%.0f ang=%d rect=%s" % [radius, step, rect])
			else:
				var reason: String = String(verdict["reason"])
				reasons[reason] = int(reasons.get(reason, 0)) + 1
	print("PROBE válidas=%d razones=%s" % [valid_found, str(reasons)])
	# Y ahora dejar correr la sim para ver si el campamento la rotura
	var sim_clock: Node = root.get_node("/root/SimClock")
	sim_clock.call("set_speed", 4)
	for _f: int in 2400:
		await process_frame
	print("PROBE huertos tras 2400 frames: %d" % get_nodes_in_group(&"farms").size())
	print(
		(
			"PROBE comida=%s checks_hambre=%s"
			% [str(game_state.call("get_resource", &"food")), str(camp.get("_hungry_checks"))]
		)
	)
	quit(0)


func get_tree_nodes_first(group: StringName) -> Node:
	var nodes: Array[Node] = get_nodes_in_group(group)
	return nodes[0] if not nodes.is_empty() else null
