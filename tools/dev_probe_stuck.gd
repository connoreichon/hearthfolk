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
	# Escenario EXACTO del soak S2: 3 bandas (4+4+2) a 500+ m, evolución
	# natural (sin cebar despensa), para reproducir el atasco de la banda sur.
	game_state.set("pending_new_seed", 24681)
	game_state.set("pending_settlers", 10)
	game_state.set("placement_pending", true)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 10:
		await process_frame
	var placer: Node = main.get_node("BandPlacer")
	var anchors: Array[Vector3] = [
		Vector3(-380.0, 0.0, -360.0), Vector3(390.0, 0.0, -340.0), Vector3(0.0, 0.0, 400.0)
	]
	var splits: Array[int] = [4, 4, 2]
	for i: int in anchors.size():
		var spot: Vector3 = placer.call("_find_valid_near", anchors[i], 12.0, 20)
		placer.call("drop_band", spot, splits[i])
	for _f: int in 10:
		await process_frame
	var south: Node3D = null
	for node: Node in get_nodes_in_group(&"camps"):
		if (node as Node3D).global_position.z > 300.0:
			south = node as Node3D
	print("probe_stuck: banda sur en %s, 7 min" % south.global_position)
	sim_clock.call("set_speed", 4)

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
					if int(_streak[cid]) >= 3:
						_dump(c, cid, float(now - start_ms) / 60000.0)
				else:
					_streak[cid] = 0
			else:
				_streak[cid] = 0
			_last[cid] = pos
	print("probe_stuck: fin")
	quit(0)


func _dump(c: Node3D, _cid: int, minute: float) -> void:
	var sm: RefCounted = c.get("state_machine")
	var agent: NavigationAgent3D = c.get("nav_agent")
	var task_id: int = int(c.get("current_task_id"))
	var task_board: Node = root.get_node("/root/TaskBoard")
	var task: RefCounted = task_board.call("get_task", task_id)
	var kind: String = str(task.get("kind")) if task != null else "-"
	var profession: String = str((c.get("data") as Resource).get("profession"))
	var fire: Vector3 = Vector3.ZERO
	var best_fire: float = INF
	for f: Node in get_nodes_in_group(&"campfire"):
		var d: float = (f as Node3D).global_position.distance_to(c.global_position)
		if d < best_fire:
			best_fire = d
			fire = (f as Node3D).global_position
	var crowd: int = 0
	for other: Node in get_nodes_in_group(&"citizens"):
		if other != c and (other as Node3D).global_position.distance_to(c.global_position) < 2.5:
			crowd += 1
	var pile_d: float = _nearest_dist(&"storage", c.global_position)
	var tree_d: float = _nearest_dist(&"trees", c.global_position)
	# ¿Contra qué se apoya el cuerpo? (última colisión de move_and_slide)
	var hit: String = "-"
	var body: CharacterBody3D = c as CharacterBody3D
	if body.get_slide_collision_count() > 0:
		var col: Object = body.get_slide_collision(0).get_collider()
		if col != null:
			hit = str((col as Node).name)
	print(
		(
			(
				"STUCK min %.1f | %s (%s) | estado=%s tarea=%s | pos=(%.1f,%.1f) target=(%.1f,%.1f) "
				+ "dist=%.2f navfin=%s reach=%s | fuego=%.1f monton=%.1f arbol=%.1f choca=%s vec=%d"
			)
			% [
				minute,
				str(c.get("data").get("display_name")),
				profession,
				str(sm.call("current_name")),
				kind,
				c.global_position.x,
				c.global_position.z,
				agent.target_position.x,
				agent.target_position.z,
				agent.distance_to_target(),
				str(agent.is_navigation_finished()),
				str(agent.is_target_reachable()),
				fire.distance_to(c.global_position),
				pile_d,
				tree_d,
				hit,
				crowd,
			]
		)
	)


func _nearest_dist(group: StringName, from: Vector3) -> float:
	var best: float = 999.0
	for node: Node in get_nodes_in_group(group):
		best = minf(best, (node as Node3D).global_position.distance_to(from))
	return best
