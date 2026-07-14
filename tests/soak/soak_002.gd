extends SceneTree
## Soak Build 002:  godot --headless --path . -s tests/soak/soak_002.gd
## 40 minutos reales a ×4 (~20 días, 2.5 años) con el bucle completo:
## tala + casa + huerto, estaciones, llegadas, moral, eventos.
## Criterios: sin atascos >15 s, tareas acotadas, ≥1 casa, población ≥5,
## comida >0 en ≥90 % de muestras tras el día 3, memoria estable, sin fugas.

const DURATION_MS: int = 40 * 60 * 1000
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
	game_state.call("setup_new_game", 24680)
	game_state.call("add_resource", &"food", 12)
	game_state.call("add_resource", &"tools", 4)
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	sim_clock.call("reset", 1, 0.25)
	sim_clock.call("set_speed", 4)
	for _f: int in 30:
		await process_frame

	# Escenario: 10 árboles marcados + casa + huerto. Después, manos fuera.
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
	print("soak002: 10 árboles + casa + huerto. 40 minutos a ×4…")

	var start_ms: int = Time.get_ticks_msec()
	var next_sample_ms: int = start_ms
	var last_positions: Dictionary = {}
	var stuck_streaks: Dictionary = {}
	var memory_at_5min: float = 0.0
	var max_entities: int = 0
	var start_entities: int = int(registry.call("count"))
	var food_samples: int = 0
	var food_zero_samples: int = 0

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
		if total_tasks > 120:
			_failures.append("tareas desbocadas: %d (min %.1f)" % [total_tasks, elapsed_min])
		if int(sim_clock.get("day")) > 3:
			food_samples += 1
			if int(game_state.call("get_resource", &"food")) <= 0:
				food_zero_samples += 1
		if int(elapsed_min * 10.0) % 40 == 0:
			print(
				(
					(
						"soak002 min %.0f | día %s (%s) | pob %d | comida %s"
						+ " | madera %s | casas %d | ent %d | tareas %d"
					)
					% [
						elapsed_min,
						str(sim_clock.get("day")),
						str(sim_clock.call("season_name")),
						get_nodes_in_group(&"citizens").size(),
						str(game_state.call("get_resource", &"food")),
						str(game_state.call("get_resource", &"wood")),
						get_nodes_in_group(&"buildings").size(),
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
	if get_nodes_in_group(&"buildings").is_empty():
		_failures.append("ninguna casa terminada")
	var population: int = get_nodes_in_group(&"citizens").size()
	if population < 5:
		_failures.append("la población no creció (pob %d)" % population)
	if food_samples > 0 and float(food_zero_samples) / float(food_samples) > 0.10:
		_failures.append(
			(
				"hambruna: comida a cero en %d/%d muestras tras el día 3"
				% [food_zero_samples, food_samples]
			)
		)
	var end_entities: int = int(registry.call("count"))
	if end_entities > start_entities + 90:
		_failures.append("posible fuga de entidades: %d→%d" % [start_entities, end_entities])

	print("---")
	print(
		(
			(
				"soak002 FINAL: día %s | pob %d | casas %d | ent %d→%d (máx %d)"
				+ " | memoria %.1f→%.1f MB | comida-cero %d/%d"
			)
			% [
				str(sim_clock.get("day")),
				population,
				get_nodes_in_group(&"buildings").size(),
				start_entities,
				end_entities,
				max_entities,
				memory_at_5min / 1048576.0,
				memory_end / 1048576.0,
				food_zero_samples,
				food_samples,
			]
		)
	)
	for failure: String in _failures:
		printerr("SOAK002 FALLO: " + failure)
	print("SOAK002 RESULTADO: %s" % ("OK" if _failures.is_empty() else "FALLOS"))
	quit(0 if _failures.is_empty() else 1)
