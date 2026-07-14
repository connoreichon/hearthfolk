extends SceneTree
## Sonda de atascos: mismo escenario que el soak, 6 minutos, y al detectar
## un atasco vuelca estado/tarea/objetivo del habitante.

var _last: Dictionary = {}
var _streak: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	var sim_clock: Node = root.get_node("/root/SimClock")
	var task_board: Node = root.get_node("/root/TaskBoard")
	game_state.call("setup_new_game", 24680)
	game_state.call("add_resource", &"food", 12)
	game_state.call("add_resource", &"tools", 4)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	sim_clock.call("reset", 1, 0.25)
	sim_clock.call("set_speed", 4)
	for _f: int in 30:
		await process_frame
	var trees: Array[Node] = get_nodes_in_group(&"trees")
	trees.sort_custom(
		func(a: Node, b: Node) -> bool:
			return (a as Node3D).global_position.length() < (b as Node3D).global_position.length()
	)
	var marked: int = 0
	for node: Node in trees:
		if marked >= 10:
			break
		if not bool(node.call("choppable")):
			continue
		node.call("set_marked", true)
		task_board.call("publish", &"chop", node.get("entity_id"), {}, 5)
		marked += 1
	var terrain: RefCounted = game_state.get("terrain")
	var nav_region: Node3D = main.get_node("World/NavigationRegion3D") as Node3D
	var site_script: GDScript = load("res://scripts/construction/construction_site.gd")
	site_script.call(
		"place",
		nav_region,
		Vector3(-9.0, float(terrain.call("get_height", -9.0, -9.0)), -9.0),
		PI * 0.25,
		9911
	)
	var farm_script: GDScript = load("res://scripts/construction/farm_field.gd")
	farm_script.call("place", nav_region, Rect2(5.0, 5.0, 6.0, 5.0))
	print("probe_stuck: en marcha, 6 min")

	var start_ms: int = Time.get_ticks_msec()
	var next_ms: int = start_ms
	while Time.get_ticks_msec() - start_ms < 6 * 60 * 1000:
		await process_frame
		var now: int = Time.get_ticks_msec()
		if now < next_ms:
			continue
		next_ms = now + 5000
		for node: Node in get_nodes_in_group(&"citizens"):
			var c: Node3D = node as Node3D
			var cid: int = int(c.get("entity_id"))
			var pos: Vector3 = c.global_position
			if bool(c.call("is_moving")) and _last.has(cid):
				if pos.distance_to(_last[cid]) < 0.08:
					_streak[cid] = int(_streak.get(cid, 0)) + 1
					if int(_streak[cid]) >= 2:
						_dump(c, cid, float(now - start_ms) / 60000.0)
				else:
					_streak[cid] = 0
			else:
				_streak[cid] = 0
			_last[cid] = pos
	print("probe_stuck: fin")
	quit(0)


func _dump(c: Node3D, cid: int, minute: float) -> void:
	var sm: RefCounted = c.get("state_machine")
	var agent: NavigationAgent3D = c.get("nav_agent")
	var task_id: int = int(c.get("current_task_id"))
	var task_board: Node = root.get_node("/root/TaskBoard")
	var task: RefCounted = task_board.call("get_task", task_id)
	var kind: String = str(task.get("kind")) if task != null else "-"
	print(
		(
			(
				"STUCK min %.1f | id %d %s | estado=%s tarea=%s | pos=%s | target=%s dist=%.2f "
				+ "| navfin=%s reachable=%s | vel=%s"
			)
			% [
				minute,
				cid,
				str(c.get("data").get("display_name")),
				str(sm.call("current_name")),
				kind,
				str(c.global_position),
				str(agent.target_position),
				agent.distance_to_target(),
				str(agent.is_navigation_finished()),
				str(agent.is_target_reachable()),
				str(c.get("velocity")),
			]
		)
	)
