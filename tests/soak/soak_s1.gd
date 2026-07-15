extends SceneTree
## Soak de puerta S1:  godot --headless --path . -s tests/soak/soak_s1.gd
## 20 minutos reales a ×4 con 3 bandas MUY separadas (500+ m) en el mapa
## gigante, manos fuera. Criterios: sin atascos >15 s, tareas acotadas,
## entidades acotadas, memoria estable, y las 3 aldeas con nombre vivas.

const DURATION_MS: int = 20 * 60 * 1000
const SAMPLE_MS: int = 5000
const STUCK_SAMPLES: int = 3
const ANCHORS: Array[Vector3] = [
	Vector3(-380.0, 0.0, -360.0), Vector3(390.0, 0.0, -340.0), Vector3(0.0, 0.0, 400.0)
]

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	var sim_clock: Node = root.get_node("/root/SimClock")
	var task_board: Node = root.get_node("/root/TaskBoard")
	var registry: Node = root.get_node("/root/EntityRegistry")
	var soak_seed: int = 24681
	if OS.get_environment("HF_SOAK_SEED") != "":
		soak_seed = int(OS.get_environment("HF_SOAK_SEED"))
	game_state.set("pending_new_seed", soak_seed)
	game_state.set("pending_settlers", 10)
	game_state.set("placement_pending", true)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _f: int in 10:
		await process_frame
	var placer: Node = main.get_node_or_null("BandPlacer")
	if placer == null:
		printerr("SOAKS1 FALLO: no hay BandPlacer")
		quit(1)
		return
	var splits: Array[int] = [4, 4, 2]
	for i: int in ANCHORS.size():
		var spot: Vector3 = placer.call("_find_valid_near", ANCHORS[i], 12.0, 20)
		if spot == Vector3.INF:
			printerr("SOAKS1 FALLO: sin sitio válido cerca de %s" % ANCHORS[i])
			quit(1)
			return
		placer.call("drop_band", spot, splits[i])
	for _f: int in 10:
		await process_frame
	var camps: Array[Node] = get_nodes_in_group(&"camps")
	print("soakS1: %d aldeas sembradas a 500+ m. 20 minutos a ×4…" % camps.size())
	for node: Node in camps:
		print(
			(
				"soakS1 aldea: %s (%s)"
				% [str(node.get("settlement_name")), str(node.call("rank_name"))]
			)
		)
	if camps.size() < 3:
		_failures.append("siembra incompleta: %d aldeas" % camps.size())
	var min_dist: float = INF
	for a: int in camps.size():
		for b: int in range(a + 1, camps.size()):
			min_dist = minf(
				min_dist,
				(camps[a] as Node3D).global_position.distance_to(
					(camps[b] as Node3D).global_position
				)
			)
	if min_dist < 450.0:
		_failures.append("aldeas demasiado juntas: %.0f m" % min_dist)
	sim_clock.call("set_speed", 4)

	var start_ms: int = Time.get_ticks_msec()
	var next_sample_ms: int = start_ms
	var last_positions: Dictionary = {}
	var stuck_streaks: Dictionary = {}
	var memory_at_5min: float = 0.0
	var start_entities: int = int(registry.call("count"))
	var max_entities: int = start_entities

	while Time.get_ticks_msec() - start_ms < DURATION_MS:
		await process_frame
		var now: int = Time.get_ticks_msec()
		if now < next_sample_ms:
			continue
		next_sample_ms = now + SAMPLE_MS
		var elapsed_min: float = float(now - start_ms) / 60000.0
		var entities: int = int(registry.call("count"))
		max_entities = maxi(max_entities, entities)
		for node: Node in get_nodes_in_group(&"citizens"):
			var citizen: Node3D = node as Node3D
			var cid: int = int(citizen.get("entity_id"))
			var pos: Vector3 = citizen.global_position
			if bool(citizen.call("is_moving")) and last_positions.has(cid):
				if pos.distance_to(last_positions[cid]) < 0.08:
					stuck_streaks[cid] = int(stuck_streaks.get(cid, 0)) + 1
					if int(stuck_streaks[cid]) >= STUCK_SAMPLES:
						_failures.append(
							(
								"habitante %d atascado >15 s en %s (min %.1f)"
								% [cid, str(pos), elapsed_min]
							)
						)
						stuck_streaks[cid] = 0
				else:
					stuck_streaks[cid] = 0
			else:
				stuck_streaks[cid] = 0
			last_positions[cid] = pos
		if memory_at_5min == 0.0 and elapsed_min >= 5.0:
			memory_at_5min = Performance.get_monitor(Performance.MEMORY_STATIC)
		var stats: Dictionary = task_board.call("stats")
		var total_tasks: int = int(stats["free"]) + int(stats["claimed"])
		if total_tasks > 140:
			_failures.append("tareas desbocadas: %d (min %.1f)" % [total_tasks, elapsed_min])
		if int(elapsed_min * 10.0) % 40 == 0:
			print(
				(
					"soakS1 min %.0f | día %s | pob %d | leña %s | ent %d | tareas %d"
					% [
						elapsed_min,
						str(sim_clock.get("day")),
						get_nodes_in_group(&"citizens").size(),
						str(game_state.call("get_resource", &"wood")),
						entities,
						total_tasks,
					]
				)
			)

	var memory_end: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	if memory_at_5min > 0.0:
		var drift: float = absf(memory_end - memory_at_5min) / memory_at_5min
		if drift > 0.10:
			_failures.append(
				(
					"memoria inestable: %.1f%% (%.1f→%.1f MB)"
					% [drift * 100.0, memory_at_5min / 1048576.0, memory_end / 1048576.0]
				)
			)
	var end_entities: int = int(registry.call("count"))
	if end_entities > start_entities + 120:
		_failures.append("posible fuga de entidades: %d→%d" % [start_entities, end_entities])

	print("---")
	print(
		(
			"soakS1 FINAL: día %s | pob %d | aldeas %d | ent %d→%d (máx %d) | mem %.1f→%.1f MB"
			% [
				str(sim_clock.get("day")),
				get_nodes_in_group(&"citizens").size(),
				get_nodes_in_group(&"camps").size(),
				start_entities,
				end_entities,
				max_entities,
				memory_at_5min / 1048576.0,
				memory_end / 1048576.0,
			]
		)
	)
	for failure: String in _failures:
		printerr("SOAKS1 FALLO: " + failure)
	print("SOAKS1 RESULTADO: %s" % ("OK" if _failures.is_empty() else "FALLOS"))
	quit(0 if _failures.is_empty() else 1)
