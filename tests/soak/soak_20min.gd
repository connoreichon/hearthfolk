extends SceneTree
## Soak test §17.3 — la prueba reina:
##   godot --headless --path . -s tests/soak/soak_20min.gd
## 20 minutos reales a ×4 (≈10 días in-game). Criterios: sin atascos >15 s,
## sin tareas desbocadas, entidades acotadas, ≥1 casa terminada, memoria
## estable ±10 % entre el minuto 5 y el 20.
## (Duck typing a propósito: el script de entrada -s compila antes que los
## autoloads y no puede referenciar clases del juego.)

const DURATION_MS: int = 20 * 60 * 1000
const SAMPLE_MS: int = 5000
const STUCK_SAMPLES: int = 3

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	var sim_clock: Node = root.get_node("/root/SimClock")
	var task_board: Node = root.get_node("/root/TaskBoard")
	var registry: Node = root.get_node("/root/EntityRegistry")
	game_state.call("setup_new_game", 8888)
	game_state.call("add_resource", &"food", 12)
	game_state.call("add_resource", &"tools", 4)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	sim_clock.call("reset", 1, 0.25)
	sim_clock.call("set_speed", 4)
	for _f: int in 30:
		await process_frame

	# Bucle completo: marcar 10 árboles cercanos + una obra que pide madera
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
	var site_pos: Vector3 = Vector3(-9.0, float(terrain.call("get_height", -9.0, -9.0)), -9.0)
	var site_script: GDScript = load("res://scripts/construction/construction_site.gd")
	var nav_region: Node3D = main.get_node("World/NavigationRegion3D") as Node3D
	site_script.call("place", nav_region, site_pos, PI * 0.25, 8899)
	print("soak: 10 árboles marcados, obra colocada. 20 minutos a ×4…")

	var start_ms: int = Time.get_ticks_msec()
	var next_sample_ms: int = start_ms
	var last_positions: Dictionary = {}
	var stuck_streaks: Dictionary = {}
	var memory_at_5min: float = 0.0
	var max_entities: int = 0
	var start_entities: int = int(registry.call("count"))

	while Time.get_ticks_msec() - start_ms < DURATION_MS:
		await process_frame
		var now: int = Time.get_ticks_msec()
		if now < next_sample_ms:
			continue
		next_sample_ms = now + SAMPLE_MS
		var elapsed_min: float = float(now - start_ms) / 60000.0
		var entities: int = int(registry.call("count"))
		max_entities = maxi(max_entities, entities)
		# Atascos: en estado de movimiento sin desplazarse 3 muestras (15 s)
		for node: Node in get_nodes_in_group(&"citizens"):
			var citizen: Node3D = node as Node3D
			var cid: int = int(citizen.get("entity_id"))
			var pos: Vector3 = citizen.global_position
			var moving: bool = bool(citizen.call("is_moving"))
			if moving and last_positions.has(cid):
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
		if int(stats["claimed"]) > 4:
			_failures.append("más tareas reclamadas que habitantes (min %.1f)" % elapsed_min)
		if int(stats["free"]) + int(stats["claimed"]) > 80:
			_failures.append(
				(
					"tareas desbocadas: %d (min %.1f)"
					% [int(stats["free"]) + int(stats["claimed"]), elapsed_min]
				)
			)
		if int(elapsed_min * 10.0) % 20 == 0:
			print(
				(
					"soak min %.1f | día %s | entidades %d | tareas %s | madera %s | casas %d"
					% [
						elapsed_min,
						str(sim_clock.get("day")),
						entities,
						str(stats),
						str(game_state.call("get_resource", &"wood")),
						get_nodes_in_group(&"buildings").size(),
					]
				)
			)

	# --- Verificación final ---
	var memory_at_20min: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	if memory_at_5min > 0.0:
		var drift: float = absf(memory_at_20min - memory_at_5min) / memory_at_5min
		if drift > 0.10:
			_failures.append(
				(
					"memoria inestable: %.1f%% entre min 5 y 20 (%.1f→%.1f MB)"
					% [drift * 100.0, memory_at_5min / 1048576.0, memory_at_20min / 1048576.0]
				)
			)
	if get_nodes_in_group(&"buildings").is_empty():
		_failures.append("ninguna casa terminada en 10 días")
	var end_entities: int = int(registry.call("count"))
	if end_entities > start_entities + 40:
		_failures.append("posible fuga de entidades: %d → %d" % [start_entities, end_entities])

	print("---")
	print(
		(
			"soak FINAL: día %s | entidades %d→%d (máx %d) | casas %d | memoria %.1f→%.1f MB"
			% [
				str(sim_clock.get("day")),
				start_entities,
				end_entities,
				max_entities,
				get_nodes_in_group(&"buildings").size(),
				memory_at_5min / 1048576.0,
				memory_at_20min / 1048576.0,
			]
		)
	)
	for failure: String in _failures:
		printerr("SOAK FALLO: " + failure)
	print("SOAK RESULTADO: %s" % ("OK" if _failures.is_empty() else "FALLOS"))
	quit(0 if _failures.is_empty() else 1)
